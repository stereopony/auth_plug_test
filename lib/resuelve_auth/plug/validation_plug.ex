defmodule ResuelveAuth.Plug.EnsureAuth do
  import Plug.Conn
  @moduledoc """
  Plug to validate token issued by Resuelve Authentication API
  """
  @expected_field "id"

  @spec init(map) :: map
  def init(opts) do
    opts = Enum.into(opts, %{})
    handler = build_handler_tuple(opts)
    %{
      handler: handler
    }
  end

  @spec call(Plug.Conn, map) :: Plug.conn
  def call(conn, opts) do
    case isAuthorized(conn, opts) do
      "UNAUTHORIZED" -> handle_error(conn, {:error, :invalid_token}, opts)
      "AUTHORIZED"   -> conn
    end
  end

  defp isAuthorized(conn, _) do
    auth_token = get_req_header(conn, "authorization")
      url = "#{System.get_env("AUTH_HOST")}/api/sessions"
      headers = ["Authorization": "#{auth_token}", "Accept": "Application/json; Charset=utf-8"]
      options = [recv_timeout: 30_000]
      response = HTTPoison.get!(url, headers, options)
      response.body
      |> Poison.decode!
      |> Map.get(@expected_field)
    end

  defp handle_error(%Plug.Conn{params: params} = conn, reason, opts) do
    conn = conn |> assign(:auth_failure, reason) |> halt
    {mod, meth} = Map.get(opts, :handler)
    apply(mod, meth, [conn, params])
  end

  defp build_handler_tuple(%{handler: mod}) do
    {mod, :unauthenticated}
  end

  defp build_handler_tuple(_) do
    {ResuelveAuth.Plug.ErrorHandler, :unauthenticated}
  end

end
