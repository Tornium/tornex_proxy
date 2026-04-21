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

defmodule TornexProxy.Router do
  @moduledoc """
  
  """

  # TODO: Add a moduledoc

  defmacro tornex_proxy(path, opts \\ []) do
    quote bind_quoted: binding() do
      import Phoenix.Router

      prefix = Phoenix.Router.scoped_path(__MODULE__, path)

      scope path, alias: false, as: false do
        get "/v1/:resource/:resource_id", TornexProxy.QueryController, :get_query
        get "/v1/:resource/", TornexProxy.QueryController, :get_query

        get "/v2/*path", TornexProxy.QueryController, :get_spec_query
      end
    end
  end
end
