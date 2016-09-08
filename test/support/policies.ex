defmodule PolicyWonk.Test.Policies do
  @behaviour PolicyWonk.Policy

  def policy(_conn, :from_config) do
    :ok
  end

  def policy_error(conn, "config_err") do
    Plug.Conn.assign(conn, :errp, "config_policy_err")
  end
end