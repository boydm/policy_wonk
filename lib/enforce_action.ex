defmodule PolicyWonk.EnforceAction do
  alias PolicyWonk.Utils

  defmodule Error do
    defexception [
      message: "PolicyWonk.EnforceAction can only be used within a controller"
    ]
  end

  #----------------------------------------------------------------------------
  def init(opts) do
    PolicyWonk.Enforce.init( %{
        handler:        opts[:handler]
      })
  end

  def call(conn, opts) do
    opts = case Utils.get_exists(conn, [:private, :phoenix_action]) do
      nil ->
        raise PolicyWonk.EnforceAction.Error
      action ->
        Map.put(opts, :policies, [action])
    end

    PolicyWonk.Enforce.call(conn, opts)
  end
end