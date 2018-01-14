defmodule PolicyWonk.Enforce do


@moduledoc """

This the main policy enforcement plug.

## Policy Enforcement

The goal of `PolicyWonk.Enforce` is to evaluate one or more policies and either halt the plug stack, or allow it to continue.

In a router:

      defmodule MyApp.Router do
        use MyApp.Web, :router

        pipeline :browser_session do
          plug PolicyWonk.LoadResource, :current_user
          plug PolicyWonk.Enforce, :current_user
        end
        
        pipeline :admin do
          plug PolicyWonk.Enforce, {:user_permission, "admin"}
        end
        
        . . .

In a controller:

      defmodule AdminController do
        use Phoenix.Controller
      
        plug PolicyWonk.Enforce, {:user_permission, "admin"}
      
        def index(conn, _params) do
          send_resp(conn, 200, "OK")
        end
      end

If any policy returns anything other than `:ok`, then the plug stack is halted and given a chance to exit gracefully.

## Specifying Policies

The main parameter to the `PolicyWonk.Enforce` plug is either a single policy or a list of policies.

      plug PolicyWonk.Enforce, :policy_1
      plug PolicyWonk.Enforce, [:policy_1, :policy_2]

The “name” of the policy can be pretty much any type you want to pass in to your policy. It doesn’t need to be an atom, although that is very convenient to match on.

These are all valid policy specifiers:

      plug PolicyWonk.Enforce, [:policy_1, :policy_2]
      plug PolicyWonk.Enforce, {:policy_s, "a string")
      plug PolicyWonk.Enforce, %{id: "an_id", data: %{color: "blue"}}

The idea is that you create matching policy functions and rely Elixir’s function matching to select the right one.

      def policy( assigns, :policy_1 ) do
        :ok
      end
      
      def policy( assigns, {:policy_2, name} ) do
        IO.inspect name
        :ok
      end
      
      def policy( assigns, %{id: id, data: %{color: color} ) do
        IO.inspect color
        :ok
      end

## Use with Guards

When the `PolicyWonk.Enforce` is invoked inside a Phoenix controller, you can add guards against the current action.

    plug PolicyWonk.Enforce, :policy_1 when action in [:index]

## Handling Policy Failures

If any policy fails, then the `PolicyWonk.Enforce` plug calls your `policy_error` function with the data returned by the policy and halts the plug stack.

This is where you transform the conn to handle the error gracefully.

## Specifying the Policy Module

As discussed in [the documentation for PolicyWonk.Policy](PolicyWonk.Policy.html#module-policy-locations), 
the `PolicyWonk.Enforce` plug will look for policies first in your controller (or router) as appropriate. Then in the policy module/s specified in the config block.

If you are using the plug outside phoenix, then just the config block is checked.

You can also specify exactly which module to look in at the time you invoke the plug.

    plug PolicyWonk.Enforce, %{policies: [:policy_1], module: MyPoliciesModule}

If you do specify the module, then that is the only one `PolicyWonk.Enforce` will look in for policies.

## Evaluating Policies Outside of the Plug

You will often want to evaluate policies outside of the plug chain. For example, to show only show UI if the user has permission to see it.

`PolicyWonk.Enforce` provides the `authorized?` API for just this purpose. It evaluates the policy and returns a simple boolean value indicating success or failure.

There are two ways to access the `authorized?` API. The first is to call it directly, specifying the module the policies are in.

The second, prettier, way is to call `use PolicyWonk.Enforce` in any modules where you implement policies. This creates a local `authorized?` function names the module for you.

      defmodule AdminController do
        use Phoenix.Controller
        use PolicyWonk.Enforce
        . . . 
        def policy(assigns, :is_admin) do
          . . .
        end
      end
      
      defmodule UserController do
        use Phoenix.Controller
        
        def show(conn, params) do
          if AdminController.authorized?( conn, :is_admin ) do
            . . . 
          else
            . . .
         end
       end
     end

Both forms of `authorized?` simulate the policy finding found in the plug.
"""

  alias PolicyWonk.Utils

  @default_otp_app      :policy_wonk

  #===========================================================================
  defmacro __using__(use_opts) do
    quote do
      @otp_app    unquote(use_opts[:otp_app])

      def init( opts ),     do: PolicyWonk.Enforce.do_init( opts, otp_app: @otp_app )
      def call(conn, opts), do: PolicyWonk.Enforce.call(conn, opts)
    end # quote
  end # defmacro


  #===========================================================================
  # define a policy error here - not found or something like that
  defmodule PolicyError do
    defexception [message: "#{IO.ANSI.red}Unable to execute a policy\n"]
  end


  #===========================================================================
  #------------------------------------------------------------------------
  @doc """
  Evaluate a policy outside of the plug stack. Returns a simple true/false `boolean` indicating
  if the policy succeeded or failed. Your `policy_error` function is **not** called in the event of
  a failure.

  ### Parameters
    * `module` A module to look for policies in. If nil, on the config policies will be used.
    * `data` Resource data to passed into your policy. If you pass a `conn` in, then the `assigns` field
      be extracted and sent to your policy.
    * `policies` A list of policies to be evaluated. Can also be a single policy.
  """
  @spec authorized?(atom, any, List.t | any, List.t) :: boolean
  def authorized?(module, conn, policies, opts \\ [])
  def authorized?(module, %Plug.Conn{} = conn, policies, opts), do:
    authorized?(module, conn.assigns, policies, opts)
  def authorized?(module, data, policies, opts) when is_list(policies) do
    modules = []
      |> Utils.append_truthy( module )
      |> Utils.append_truthy( config_policies(opts[:otp_app] || @default_otp_app) )

    case evaluate_policies(modules, data, policies) do
      :ok -> true
      _   -> false
    end
  end
  def authorized?(module, data, policy, opts), do:
    authorized?(module, data, [policy], opts)


  #===========================================================================
  @doc """
  Initialize an invocation of the plug.
  
  [See the discussion of specifying policies above.](PolicyWonk.Enforce.html#module-specifying-the-policy-module)
  """

  def init(%{policies: []}), do: init_empty_policies_error()

  # the main init function
  def init(%{policies: policies} = opts) when is_list(policies) do
    %{
      policies:   policies,
      module:     opts[:module] || nil,
      otp_app:    opts[:otp_app] || @default_otp_app
    }
  end

  # put the policies into a list
  def init(%{policies: policies} = opts) do
    opts
    |> Map.put(:policies, [policies])
    |> init()
  end

  # just a policy or policies were passed in a list
  def init(policies) when is_list(policies),  do: init( %{policies: policies} )
  def init(policy),                           do: init( %{policies: [policy], module: nil} )


  #--------------------------------------------------------
  defp init_empty_policies_error() do
    msg = "PolicyWonk.Enforce requires at least one policy reference"
    raise %PolicyWonk.Enforce.PolicyError{ message: msg }
  end

  #--------------------------------------------------------
  @doc false
  def do_init(pol_opts, opts) when is_map(pol_opts),  do: init( Map.put(pol_opts, :otp_app, opts[:otp_app]))
  def do_init(policies, opts) when is_list(policies), do: init( %{policies: policies, module: nil, otp_app: opts[:otp_app]} )
  def do_init(policy, opts),                          do: init( %{policies: [policy], module: nil, otp_app: opts[:otp_app]} )

  #----------------------------------------------------------------------------
  #------------------------------------------------------------------------
  @doc """
  Call is used by the plug stack. 
  """
  def call(conn, opts) do
    # figure out what module to use
    module = opts.module ||
      Utils.controller_module(conn) ||
      Utils.router_module(conn)

    modules = []
      |> Utils.append_truthy( module )
      |> Utils.append_truthy( config_policies(opts[:otp_app]) )

    # evaluate the policies. Cal error func if any fail
    case evaluate_policies( modules, conn.assigns, opts.policies ) do
      :ok ->
        # continue without transforming the conn
        conn
      err_data ->
        # halt the plug chain
        call_policy_error( modules, conn, err_data )
        |> Plug.Conn.halt
    end
  end # def call


  #----------------------------------------------------------------------------
  defp evaluate_policies(modules, data, policies ) do
    modules = Enum.uniq(modules)
    policies = Enum.uniq(policies)
    # Enumerate through all the policies. Fail if any fail
    Enum.reduce_while( policies, :ok, fn(policy, _acc) ->
      #case module.Enforce( conn, policy ) do
      case call_policy( modules, data, policy ) do
        :ok ->      {:cont, :ok}
        err_data -> {:halt, err_data }
      end
    end)
  end


  #----------------------------------------------------------------------------
  defp call_policy( modules, assigns, policy ) do
    try do
      Utils.call_down_list(modules, {:policy, [assigns, policy]})
    catch
      # if a match wasn't found on the module, try the next in the list
      :not_found ->
        # policy wasn't found on any module. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}policy#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}Policy: #{IO.ANSI.yellow}#{inspect(policy)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_modules_msg( modules ) <>
          IO.ANSI.red
        raise %PolicyWonk.Enforce.PolicyError{ message: msg }
    end
  end

  #----------------------------------------------------------------------------
  defp call_policy_error(modules, conn, err_data ) do
    try do
      Utils.call_down_list(modules, {:policy_error, [conn, err_data]})
    catch
      # if a match wasn't found on the module, try the next in the list
      :not_found ->
        # policy wasn't found on any module. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}policy_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_modules_msg( modules ) <>
          IO.ANSI.red
        raise %PolicyWonk.Enforce.PolicyError{ message: msg }
    end
  end

  #----------------------------------------------------------------------------
  defp config_policies( otp_app ) do
    Application.get_env(otp_app, PolicyWonk)[:policies]
  end

end