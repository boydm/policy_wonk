defmodule PolicyWonk.Policy do
  @moduledoc """

  # Overview

  A policy is a function that makes a simple yes/no decision.

        # ensure a user is signed in
        def policy( assigns, :current_user ) do
          case assigns[:current_user] do
            %MyApp.Account.User{} -> :ok
            _ ->    {:error, :current_user}
          end
        end

  The :current_user policy in the above module checks if a User map is assigned in the conn
  if yes, then the policy succeeds. If not, then it fails.

  You create policies that can check anything you want. In the end it will return either :ok
  or {:error, message} to indicate success or fail.

  These policies are, in turn, enforced in a plug or the other helper functions that
  are provided. (described below)

  In general, if a policy that is being enforced in the plug chain fails, it halts the plug
  and handles the error before the request controller action is ever run. This front-loads
  the authorization checks and lets you apply them to many controller/actions using router
  pipelines as a choke point.

  ## Usage

  The only way you should directly use the `PolicyWonk.Policy` module is to call
  `use PolicyWonk.Policy` when defining your policy module.

  `use PolicyWonk.Policy` injects the `enforce/2`, `enforce!/2`, and `authorized?/2`
  functions into your Policy modules. These run and evaluate your policies and act
  accordingly on the results.

  **It is expected that you will primarily use the `enforce/2`, `enforce!/2`,
  and `authorized?/2 functions in your Policy module.** These injected functions, prepare
  and call the `enforce/3`, `enforce!/3`, and `authorized?/3 functions in this module which
  are presented here for completeness.

  Example Policy Module:

        defmodule MyAppWeb.Policies do
          use PolicyWonk.Policy         # set up support for policies
          use PolicyWonk.Enforce        # turn this module into an enforcement plug

          def policy( assigns, :current_user ) do
            case assigns[:current_user] do
              %MyApp.Account.User{} ->
                :ok
              _ ->
                {:error, :current_user}
            end
          end

          def policy_error(conn, :current_user) do
            MyAppWeb.ErrorHandlers.unauthenticated(conn, "Must be logged in")
          end
        end

  # Policies

  A policy is a function that makes a simple yes/no decision. It is given the assigns field from
  the current conn, and term that identifies the policy and optionally passes in any other
  data you may need. 

  The idea is that you define multiple policy functions and rely on Elixir’s pattern matching
  to find the right one. If you use a tuple (or a map - or whatever) as the second parameter, then you can 
  have more complex calls to your policies.

        def policy( assigns, {:permission, perms} ) when is_list(perms) do
          case assigns.current_user.permissions do
            nil -> {:error, :unauthorized}        # Fail. No permissions
            user_perms ->
              Enum.all?(perms, fn(p) -> Enum.member?(user_perms, to_string(p)) end)
              |> case do
                true -> :ok                   # Success.
                false -> {:error, :unauthorized}  # Fail. Permission missing
              end
          end
        end
        def policy( assigns, {:user_permission, one_perm} ), do:
          policy( assigns, {:user_perm, [one_perm]} )


  The {:permission, perms} policy gets a permissions list from the :current_user field that
  has already been assigned. I am assuming that the policy :current_user is enforced before
  this one, so that fails, the {:permission, perms} policy won't be called.

  This is the one of the most complex policies I use. By passing in {:permission, perms}
  to identify the policy, I rely on Elixir to match on the :permission atom and can pass
  aditional data through the perms term.

  It is typically called like this

        plug MyAppWeb.Policies, {:permission, "dashboard"}
        # or
        plug MyAppWeb.Policies, {:permission, ["dashboard", "premium"]}


  **Note**: when you attach permissions to a user record in you DB, *please* use something
  like [Cloak](https://hex.pm/packages/cloak) to encrypt those values.

  ## Use outside the plug chain
  Policies are usually called from one of the enforce plugs, but can also be used to decide if a user has permission to see a piece of UI and some other thing.

  You can evaluate policies within templates, actions, and other code by using the `authorized?` function. [See documentation for `PolicyWonk.Enforce` for details](PolicyWonk.Enforce.html#module-evaluating-policies-outside-of-the-plug).
   
  ## Policy Failures

  When a policy returns anything other than `:ok`, that is interpreted as a policy failure.

  When the policy is called from a plug (as opposed to `authorized?`), then your `policy_error(conn, error_data)` function is called. You should define at least one of these functions in same place you put your policies.

        def policy_error(conn, err_data) do
          conn
          |> put_flash(:error, "Unauthorized")
          |> redirect(to: session_path(conn, :new))
        end

  The `policy_error` function works just like a regular plug function. It takes a `conn`, and whatever was returned from the policy. You can manipulate the `conn` however you want to respond to that error. Then return the `conn`.

  Since the policy failed, the `Enforce` plug will make sure `Plug.Conn.halt(conn)` is called.

  ## Policy Locations

  When a policy is used in a single controller, then it should be defined on that controller. Same for the router. 

  If a policy is used in multiple locations, then you should define it in a central policies.ex file that you refer to in your configuration data.

  In general, when you invoke the `PolicyWonk.Enforce` or `PolicyWonk.EnforceAction` plugs, they detect if the incoming `conn` is being processed by a Phoenix controller or router. It looks in the appropriate controller or router for a matching policy first. If it doesn’t find one, it then looks in policy module specified in the configuration block.

  This creates a form of policy inheritance/polymorphism. The controller (or router) calling the plug always has the authoritative say in what policy to use.

  You can also specify the policy’s module when you invoke the Enforce or EnforceAction plugs. This will be the only module the plug looks for a policy in.

  """

  @doc """
  Define a policy. Accepts a map of resources and a policy identifier.

  When called by the `PolicyWonk.Enforce` or `PolicyWonk.EnforceAction` plugs, the map will be the assigns field from the current conn.

  Returns either `:ok`, or error_data that is passed to your `policy_error` function.
  """
  @callback policy(Map.t(), any) :: :ok | {:error, any}

  @doc """
  Handle a failed policy. Called during the plug chain.

  The second parameter is whatever was returned from your `policy` function other than :ok.

  Must return a conn, which you are free to transform.
  """

  @callback policy_error(Plug.Conn.t(), any) :: Plug.Conn.t()

  @format_error "Policies must return either :ok or an {:error, message} tuple"

  # ===========================================================================
  # define a policy error here - not found or something like that
  defmodule Error do
    @moduledoc false
    defexception message: "#{IO.ANSI.red()}Policy Failure\n", module: nil, policy: nil
  end

  # ===========================================================================
  defmacro __using__(_use_opts) do
    quote do
      @behaviour PolicyWonk.Policy

      # ----------------------------------------------------
      def enforce(conn, policies), do: PolicyWonk.Policy.enforce(conn, __MODULE__, policies)
      def enforce!(conn, policies), do: PolicyWonk.Policy.enforce!(conn, __MODULE__, policies)

      # ----------------------------------------------------
      def authorized?(conn, policies),
        do: PolicyWonk.Policy.authorized?(conn, __MODULE__, policies)
    end

    # quote
  end

  # defmacro

  # ===========================================================================
  # internal functions from here down

  # ----------------------------------------------------
  # Enforce called as a (internal) plug
  def enforce(conn, module, policies)

  # don't do anything if the conn is already halted
  def enforce(%Plug.Conn{halted: true} = conn, _, _), do: conn

  # enforce a list of policies
  def enforce(%Plug.Conn{} = conn, module, policies) when is_list(policies) do
    Enum.reduce(policies, conn, &enforce(&2, module, &1))
  end

  # enforce a single policy
  def enforce(%Plug.Conn{} = conn, module, policy) do
    case module.policy(conn.assigns, policy) do
      :ok ->
        conn

      {:error, message} ->
        # halt the plug chain
        conn
        |> module.policy_error(message)
        |> Plug.Conn.halt()

      _ ->
        raise_error(@format_error, module, policy)
    end
  end

  # ----------------------------------------------------
  # enforce that either returns :ok or raises an error
  def enforce!(conn, module, policies)

  # enforce! a list of policies
  def enforce!(%Plug.Conn{} = conn, module, policies) when is_list(policies) do
    Enum.each(policies, &enforce!(conn, module, &1))
  end

  # enforce! a single policies
  def enforce!(%Plug.Conn{} = conn, module, policy) do
    case module.policy(conn.assigns, policy) do
      :ok ->
        :ok

      {:error, message} ->
        raise Error, message: message, module: module, policy: policy

      _ ->
        raise_error(@format_error, module, policy)
    end
  end

  # ----------------------------------------------------
  def authorized?(conn, module, policies)

  # enforce? that a list of policies pass
  def authorized?(%Plug.Conn{} = conn, module, policies) when is_list(policies) do
    Enum.all?(policies, &authorized?(conn, module, &1))
  end

  # enforce? a single policy
  def authorized?(%Plug.Conn{} = conn, module, policy) do
    case module.policy(conn.assigns, policy) do
      :ok ->
        true

      {:error, _} ->
        false

      _ ->
        raise_error(@format_error, module, policy)
    end
  end

  # ----------------------------------------------------------------------------
  defp raise_error(message, module, policy) do
    message =
      message <>
        "\n" <>
        "#{IO.ANSI.green()}module: #{IO.ANSI.yellow()}#{inspect(module)}\n" <>
        "#{IO.ANSI.green()}policy: #{IO.ANSI.yellow()}#{inspect(policy)}\n" <>
        IO.ANSI.default_color()

    raise Error, message: message, module: module, policy: policy
  end
end
