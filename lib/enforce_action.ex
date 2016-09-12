defmodule PolicyWonk.EnforceAction do

@moduledoc """

This plug enforces policies for each action in a Phoenix controller.

`PolicyWonk.EnforceAction` must be invoked from within a Phoenix controller. Using it anywhere else will raise the error `PolicyWonk.EnforceAction.ControllerRequired`

## Policy Enforcement

The goal of `PolicyWonk.EnforceAction` is to automatically evaluate a policy for each action in your controller.

      defmodule AdminController do
        use Phoenix.Controller
      
        plug PolicyWonk.EnforceAction
        
        . . .
      end

Is equivalent to…

      defmodule AdminController do
        use Phoenix.Controller
      
        plug PolicyWonk.Enforce, :index  when action in [:index]
        plug PolicyWonk.Enforce, :show   when action in [:show]
        plug PolicyWonk.Enforce, :new    when action in [:new]
        plug PolicyWonk.Enforce, :create when action in [:create]
        # and so on for all the actions…
        
        . . .
      end

## Use with Guards  

You can use `PolicyWonk.EnforceAction` with action guards

    defmodule AdminController do
        use Phoenix.Controller
      
        plug PolicyWonk.EnforceAction when action in [:index, :show]
        
        . . .
      end

## Specifying the policy module

You do not need to specify a policy module when you use `PolicyWonk.EnforceAction`. It will default to looking for policies in the controller it is invoked from first, then the policy modules in the config block.

*It is recommended to place policies specific to one controller in that controller module.* This keeps your policies nice and organized.

If you do wish to specify a policy module, you can pass that in as a paramter.

      defmodule AdminController do
        use Phoenix.Controller
      
        plug PolicyWonk.EnforceAction, SomeOtherModule
        
        . . .
      end

"""

  alias PolicyWonk.Utils

  defmodule ControllerRequired do
    defexception [message:
      "ActionPolicy must be plugged within a Phoenix controller\n"
    ]
  end

  #----------------------------------------------------------------------------
  # explicitly setting the module is optional
  @doc """
  Initialize the plug

  The only option for initializing `PolicyWonk.EnforceAction` is to specify the module to look for policies in. Usually left empty.

  ### Parameters
    * `module` Specify a module for policies. Default is `nil`
  """

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
