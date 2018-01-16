defmodule PolicyWonk.Enforce do
  @moduledoc """

  This the main policy enforcement plug.

  ## Policy Enforcement

  The goal of `PolicyWonk.Enforce` is to evaluate one or more policies and either halt the plug stack, or allow it to continue.

  In a router:

        defmodule MyApp.Router do
          use MyApp.Web, :router

          pipeline :browser_session do
            plug PolicyWonk.Load, :current_user
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

  # ===========================================================================
  defmacro __using__(use_opts) do
    quote do
      def init(policies_or_opts) do
        case Keyword.keyword?(policies_or_opts) do
          true ->
            policies_or_opts
            |> Keyword.put_new(:policy_module, unquote(use_opts[:policy_module]) || __MODULE__)
            |> PolicyWonk.Enforce.init()

          false ->
            PolicyWonk.Enforce.init(policy_module: __MODULE__, policies: policies_or_opts)
        end
      end

      def call(conn, opts), do: PolicyWonk.Enforce.call(conn, opts)
    end

    # quote
  end

  # defmacro

  # ===========================================================================
  # define a policy enforcement error here
  defmodule Error do
    @moduledoc false
    defexception message: "#{IO.ANSI.red()}Policy endforcement failed#{IO.ANSI.default_color()}\n"
  end

  # ===========================================================================
  @doc """
  Initialize an invocation of the plug.

  [See the discussion of specifying policies above.](PolicyWonk.Enforce.html#module-specifying-the-policy-module)
  """

  def init(opts) when is_list(opts), do: do_init(opts[:policy_module], opts[:policies])

  defp do_init(nil, _),
    do:
      raise(
        Error,
        message: "#{IO.ANSI.red()}Must supply a valid :policy_module#{IO.ANSI.default_color()}"
      )

  defp do_init(_, []),
    do:
      raise(
        Error,
        message:
          "#{IO.ANSI.red()}Must supply at least one policy to enforce#{IO.ANSI.default_color()}"
      )

  defp do_init(policy_module, policies) when is_atom(policy_module) and is_list(policies) do
    %{
      policy_module: policy_module,
      policies: policies
    }
  end

  defp do_init(policy_module, policy) do
    do_init(policy_module, [policy])
  end

  # ----------------------------------------------------------------------------
  # ------------------------------------------------------------------------
  @doc """
  Call is used by the plug stack. 
  """
  def call(conn, %{policy_module: policy_module, policies: policies}) do
    PolicyWonk.Policy.enforce(conn, policy_module, policies)
  end
end
