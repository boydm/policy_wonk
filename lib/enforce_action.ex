defmodule PolicyWonk.EnforceAction do

  defmodule ActionPolicyError do
    defexception [
      message: "PolicyWonk.EnforceAction can only be used within a controller"
    ]
  end

  #----------------------------------------------------------------------------
  def init(opts) do
    PolicyWonk.Enforce.init( %{
        handler:        opts[:handler],
        error_handler:  opts[:error_handler]
      })
  end

  def call(conn, opts) do
    opts = case conn.private[:phoenix_action] do
      nil ->
        raise ActionPolicyError
      action ->
        Map.put(opts, :policies, [action])
    end

    PolicyWonk.Enforce.call(conn, opts)
  end
end