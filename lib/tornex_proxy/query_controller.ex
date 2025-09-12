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

  @path_modules :code.all_available()
                |> Enum.map(fn {mod, _, _} -> mod |> to_string() end)
                |> Enum.filter(fn mod ->
                  mod |> String.starts_with?("Elixir.Torngen.Client.Path.")
                end)
                |> Enum.map(fn mod -> mod |> String.to_atom() end)
  :code.ensure_modules_loaded(@path_modules)

  @timeout Application.compile_env(:tornex_proxy, :timeout, :infinity)

  @spec maybe_to_integer(string :: String.t() | nil) :: integer() | String.t()
  defp maybe_to_integer(string) when is_nil(string) do
    nil
  end

  defp maybe_to_integer(string) do
    try do
      String.to_integer(string)
    rescue
      ArgumentError ->
        string
    end
  end

  defp key(headers, %{} = params) when is_list(headers) do
    Enum.find(headers, fn
      {"Authorization", "ApiKey " <> api_key} when is_binary(api_key) ->
        true

      _ ->
        false
    end) || Map.get(params, "key")
  end

  defp key_owner(headers, %{} = params) when is_list(headers) do
    Enum.find(headers, fn
      {"User-ID", user_id} when is_binary(user_id) ->
        true

      {"X-User-ID", user_id} when is_binary(user_id) ->
        true

      _ ->
        false
    end) || Map.get(params, "user_id") || 0
  end

  defp nice(headers, %{} = params) when is_list(headers) do
    Enum.find(headers, fn
      {"Nice", user_id} when is_binary(user_id) ->
        true

      {"X-Nice", user_id} when is_binary(user_id) ->
        true

      _ ->
        false
    end) || Map.get(params, "nice") || 0
  end

  def get_query(%Plug.Conn{req_headers: headers} = conn, %{"resource" => resource} = params)
      when is_binary(resource) do
    query_key = key(headers, params)
    # TODO: Raise an error if key not set

    query_key_owner = key_owner(headers, params)
    query_nice = nice(headers, params)
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
      |> IO.inspect()
      |> Tornex.Scheduler.Bucket.enqueue(timeout: @timeout)

    json(conn, response)
  end

  def get_spec_query(%Plug.Conn{req_headers: headers} = conn, %{"path" => path_segments} = params) do
    full_path = Enum.join(path_segments, "/") |> IO.inspect(label: "Path")

    query_key = key(headers, params)
    query_key_owner = key_owner(headers, params)
    query_nice = nice(headers, params)

    {path, selections} =
      Torngen.Client.Path.path_selection(full_path) |> IO.inspect(label: "path parts")

    selections =
      if is_nil(selections) do
        params
        |> Map.get("selections", "")
        |> String.split(",")
      else
        [selections]
      end
      |> IO.inspect()

    path_modules =
      Enum.filter(@path_modules, fn mod ->
        function_exported?(mod, :path, 0) and
          mod |> apply(:path_selection, []) |> elem(0) == path and
          Enum.member?(selections, mod |> apply(:path_selection, []) |> elem(1))
      end)
      |> IO.inspect()

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
          |> IO.inspect()
          |> Tornex.Scheduler.Bucket.enqueue(timeout: @timeout)
      end

    json(conn, response)
  end
end
