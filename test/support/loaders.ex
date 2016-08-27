defmodule PolicyWonk.Test.Loaders do
  #----------------------------------------------------------------------------
  def load_resource(_conn, :from_config, _params) do
    {:ok, "from_config"}
  end
end