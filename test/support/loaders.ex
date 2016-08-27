defmodule PolicyWonk.Test.Loaders do
  #----------------------------------------------------------------------------
  def load_resource(_conn, :from_config, _params) do
    {:ok, "from_config"}
  end

  #----------------------------------------------------------------------------
  def load_error( conn, :from_config, _params ) do
    Plug.Conn.assign(conn, :errl, "config_load_err")
  end
end