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

  def get_query(%Plug.Conn{req_headers: headers} = conn, %{"resource" => resource} = params)
      when is_binary(resource) do
    key =
      Enum.find(headers, fn
        {"Authorization", "ApiKey " <> api_key} when is_binary(api_key) ->
          true

        _ ->
          false
      end) || Map.get(params, "key")
    # TODO: Raise an error if not set

    key_owner =
      Enum.find(headers, fn
        {"User-ID", user_id} when is_binary(user_id) ->
          true

        {"X-User-ID", user_id} when is_binary(user_id) ->
          true

        _ ->
          false
      end) || Map.get(params, "user_id") || 0

    nice =
      Enum.find(headers, fn
        {"Nice", user_id} when is_binary(user_id) ->
          true

        {"X-Nice", user_id} when is_binary(user_id) ->
          true

        _ ->
          false
      end) || Map.get(params, "nice") || 0

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
        key: key,
        key_owner: key_owner |> maybe_to_integer(),
        nice: nice |> maybe_to_integer(),
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
      |> Tornex.Scheduler.Bucket.enqueue()

    json(conn, response)
  end

  def get_spec_query(conn, %{"path" => path_segments} = params) do
    path = Enum.join(path_segments, "/")

    json(conn, %{})
  end
end
