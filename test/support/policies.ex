defmodule PolicyWonk.Test.Policies do
  def policy(conn, :from_config) do
    {:ok, Plug.Conn.assign(conn, :found, "from_config")}
  end

  def policy_error(conn, "config_err") do
    Plug.Conn.assign(conn, :errp, "config_policy_err")
  end
end