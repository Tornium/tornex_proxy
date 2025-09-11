defmodule TornexProxyDev.Router do
  use Phoenix.Router, helpers: false
  import TornexProxy.Router

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through :api

    tornex_proxy "/api"
  end
end

defmodule TornexProxyDev.Endpoint do
  use Phoenix.Endpoint, otp_app: :tornex_proxy

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(TornexProxyDev.Router)
end

defmodule TornexProxyDev.ErrorJSON do
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end

Application.put_env(:tornex_proxy, TornexProxyDev.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  check_origin: false,
  debug_errors: false,
  http: [port: 4000],
  url: [host: "localhost"],
  json_library: :jason
)
Application.put_env(:phoenix, :serve_endpoints, true)
Application.put_env(:phoenix, :persistent, true)

Tornex.Telemetry.attach_default_logger()

{:ok, _} =
  Supervisor.start_link(
    [
      {TornexProxyDev.Endpoint, render_errors: [formats: [json: TornexProxyDev.ErrorJSON]]},
      Tornex.Scheduler.Supervisor,
      Tornex.HTTP.FinchClient
    ],
    strategy: :one_for_one
  )

Process.sleep(:infinity)
