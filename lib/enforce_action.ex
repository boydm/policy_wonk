defmodule PolicyWonk.EnforceAction do

@moduledoc """
PolicyWonk.EnforceAction docs here
"""

  alias PolicyWonk.Utils

  defmodule ControllerRequired do
    defexception [message:
      "ActionPolicy must be plugged within a Phoenix controller\n"
    ]
  end

  #----------------------------------------------------------------------------
  # explicitly setting the handler is optional
  def init( handler \\ nil )
  def init( handler ) when is_atom(handler) do
    %{handler: handler}
  end
  def init([]), do: init( nil )

  #----------------------------------------------------------------------------
  def call(conn, opts) do
    handler = case (opts.handler || Utils.controller_module(conn)) do
      nil -> raise PolicyWonk.EnforceAction.ControllerRequired
      handler -> handler
    end

    action = case Utils.action_name(conn) do
      nil -> raise PolicyWonk.EnforceAction.ControllerRequired
      action -> action
    end

    opts = %{
      policies: [action],
      handler:  handler
    }

    # evaluate the policy
    PolicyWonk.Enforce.call(conn, opts)
  end # def call

end


#  def action_name(conn), do: conn.private.phoenix_action
#  def controller_module(conn), do: conn.private.phoenix_controller
#  def router_module(conn), do: conn.private.phoenix_router
#  def endpoint_module(conn), do: conn.private.phoenix_endpoint
