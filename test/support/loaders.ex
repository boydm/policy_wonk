defmodule PolicyWonk.Test.Loaders do
  @behaviour PolicyWonk.Loader

  #----------------------------------------------------------------------------
  def load_resource(_conn, :from_config, _params) do
    {:ok, :from_config, "from_config"}
  end

  #----------------------------------------------------------------------------
  def load_error(conn, :from_config) do
    conn
  end
end