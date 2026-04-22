# Copyright 2025 tiksan
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule TornexProxy.QueryController do
  use Phoenix.Controller
  import Plug.Conn
  require Logger

  @path_modules :code.all_available()
                |> Enum.map(fn {mod, _, _} -> to_string(mod) end)
                |> Enum.filter(&String.starts_with?(&1, "Elixir.Torngen.Client.Path"))
                |> Enum.map(&String.to_atom/1)
  :code.ensure_modules_loaded(@path_modules)

  @timeout Application.compile_env(:tornex_proxy, :timeout, :infinity)

  @spec maybe_to_integer(string :: String.t() | nil) :: integer() | String.t()
  defp maybe_to_integer(string) when is_nil(string) do
    nil
  end

  defp maybe_to_integer(value) when is_integer(value) do
    value
  end

  defp maybe_to_integer(string) do
    try do
      String.to_integer(string)
    rescue
      ArgumentError ->
        string
    end
  end

  @spec key!(conn :: Plug.Conn.t(), params :: map()) :: String.t() | nil
  defp key!(%Plug.Conn{} = conn, %{} = params) do
    case get_req_header(conn, "authorization") do
      [<<"ApiKey ", api_key::binary-size(16)>>] ->
        api_key

      [] ->
        Map.get(params, "key", nil)

      api_key -> 
        Logger.warning("Invalid API key shape: #{inspect(api_key)}")
        Map.get(params, "key", nil)
    end
  end

  @spec key_owner!(conn :: Plug.Conn.t(), params :: map()) :: pos_integer()
  defp key_owner!(%Plug.Conn{} = conn, %{} = params) do
    case {get_req_header(conn, "user-id"), get_req_header(conn, "x-user-id")} do
      {[user_id], _} when is_binary(user_id) ->
        maybe_to_integer(user_id)

      {_, [user_id]} when is_binary(user_id) ->
        maybe_to_integer(user_id)

      {[], []} ->
        params
        |> Map.get("user_id", 0)
        |> maybe_to_integer()
    end
  end

  @spec nice!(conn :: Plug.Conn.t(), params :: map()) :: -20..20
  defp nice!(%Plug.Conn{} = conn, %{} = params) do
    case {get_req_header(conn, "nice"), get_req_header(conn, "x-nice")} do
      {[niceness], _} ->
        maybe_to_integer(niceness)

      {_, [niceness]} ->
        maybe_to_integer(niceness)

      {[],[]} ->
        Map.get(params, "nice", 0)
    end
  end

  def get_query(%Plug.Conn{} = conn, %{"resource" => resource} = params)
      when is_binary(resource) do
    query_key = key!(conn, params)
    # TODO: Raise an error if key not set

    query_key_owner = key_owner!(conn, params)
    query_nice = nice!(conn, params)
    resource_id = Map.get(params, "resource_id")

    selections =
      params
      |> Map.get("selections", "")
      |> String.split(",")
      |> Enum.reject(fn selection -> selection == "" end)

    query_params =
      params
      |> Map.reject(fn {key, _value} ->
        Enum.member?(
          [
            "user_id",
            "nice",
            "key",
            "key_owner",
            "resource",
            "resource_id",
            "selections",
            "to",
            "from",
            "limit",
            "sort"
          ],
          key
        )
      end)
      |> Enum.into([], fn {k, v} -> {String.to_atom(k), v} end)

    response =
      %Tornex.Query{
        key: query_key,
        key_owner: query_key_owner |> maybe_to_integer(),
        nice: query_nice |> maybe_to_integer(),
        resource: resource,
        resource_id: maybe_to_integer(resource_id),
        selections: selections,
        from: Map.get(params, "from", nil) |> maybe_to_integer(),
        to: Map.get(params, "to", nil) |> maybe_to_integer(),
        limit: Map.get(params, "limit", nil) |> maybe_to_integer(),
        sort: Map.get(params, "sort", nil),
        params: query_params
      }
      |> Tornex.Scheduler.Bucket.enqueue(timeout: @timeout)

    json(conn, response)
  end

  def get_spec_query(%Plug.Conn{} = conn, %{"path" => path_segments} = params) do
    full_path = Enum.join(path_segments, "/")

    query_key = key!(conn, params)
    query_key_owner = key_owner!(conn, params)
    query_nice = nice!(conn, params)

    {path, selections} = Torngen.Client.Path.path_selection(full_path)

    selections =
      if is_nil(selections) do
        params
        |> Map.get("selections", "")
        |> String.split(",")
      else
        [selections]
      end

    path_modules =
      Enum.filter(@path_modules, fn mod ->
        function_exported?(mod, :path, 0) and
          mod |> apply(:path_selection, []) |> elem(0) == path and
          Enum.member?(selections, mod |> apply(:path_selection, []) |> elem(1))
      end)

    response =
      cond do
        is_nil(query_key) ->
          %{error: %{code: 1, error: "Key is empty"}}

        path_modules == [] ->
          # Invalid path
          %{error: %{code: 0, error: "Invalid query path"}}

        is_list(path_modules) ->
          IO.inspect(path_modules, label: "Query modules")

          opts = [
            nice: maybe_to_integer(query_nice),
            key: query_key,
            key_owner: maybe_to_integer(query_key_owner)
          ]

          path_modules
          |> Enum.reduce(Tornex.SpecQuery.new(opts), fn mod, query ->
            Tornex.SpecQuery.put_path(query, mod)
          end)
          |> Tornex.Scheduler.Bucket.enqueue(timeout: @timeout)
      end

    json(conn, response)
  end
end
