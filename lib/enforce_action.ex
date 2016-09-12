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
  # explicitly setting the module is optional
  def init( module \\ nil )
  def init( module ) when is_atom(module) do
    %{module: module}
  end
  def init([]), do: init( nil )

  #----------------------------------------------------------------------------
  @doc """
  Call is used by the plug stack. 
  """
  def call(conn, opts) do
    module = case (opts.module || Utils.controller_module(conn)) do
      nil -> raise PolicyWonk.EnforceAction.ControllerRequired
      module -> module
    end

    action = case Utils.action_name(conn) do
      nil -> raise PolicyWonk.EnforceAction.ControllerRequired
      action -> action
    end

    opts = %{
      policies: [action],
      module:  module
    }

    # evaluate the policy
    PolicyWonk.Enforce.call(conn, opts)
  end # def call

end


#  def action_name(conn), do: conn.private.phoenix_action
#  def controller_module(conn), do: conn.private.phoenix_controller
#  def router_module(conn), do: conn.private.phoenix_router
#  def endpoint_module(conn), do: conn.private.phoenix_endpoint
