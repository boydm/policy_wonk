defmodule PolicyWonk.Policy do
  @moduledoc """

  # Overview

  A policy is a function that makes a simple yes/no decision. This decision can then be
  inserted into your plug chain to enforce authorization rules at the router.

  Simple policy example:

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

  The only time you should directly use the `PolicyWonk.Policy` module is to call
  `use PolicyWonk.Policy` when defining your policy module.

  `use PolicyWonk.Policy` injects the `enforce/2`, `enforce!/2`, and `authorized?/2`
  functions into your Policy modules. These run and evaluate your policies and act
  accordingly on the results.

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

  ## Injected functions

  When you call `use PolicyWonk.Policy`, the following functions are injected into your module.

  ### enforce/2

  `enforce(conn, policy)`

  Callable as a local plug. Enforce accepts the current conn and a policy indicator.
  It then calls the policy, evaluates the response and either passes or transforms
  the conn with a failure.

  You will normally only use this function if you want to enforce a policy that is
  written into a controller. Then the plug call will look like this:

        plug :enforce, :some_policy


  If you want to enforce a policy from your router, please read the `PolicyWonk.Enforce`
  documentation.

  parameters:

  * `conn` The current conn in the plug chain
  * `policy` The policy or policies you want to enforce. This can be either a single
  term representing one policy, or a list of policy terms.

  ### enforce!/2

  `enforce!/2`

  Evaluates one or more policies and either returns :ok (success) or raises an error.

  This is useful for enforcing a policy within an action in a controller.

  * `conn` The current conn in the plug chain
  * `policy` The policy or policies you want to enforce. This can be either a single
  term representing one policy, or a list of policy terms.

  ### authorized/2

  `authorized?/2`

  Evaluates one or more policies and either returns `true` (success) or `false` (failure).

  This is useful for choosing whether or not to render portions of a template, or for
  conditional logic in a controller.

  * `conn` The current conn in the plug chain
  * `policy` The policy or policies you want to enforce. This can be either a single
  term representing one policy, or a list of policy terms.


  # Policies

  A policy is a function that makes a simple yes/no decision. It is given the assigns field from
  the current conn, and term that identifies the policy and optionally passes in any other
  data you may need. 

  The idea is that you define multiple policy functions and rely on Elixir’s pattern matching
  to find the right one. If you use a tuple (or a map - or whatever) as the second parameter, then you can 
  have more complex calls to your policies.

  The following example, checks to see if a given permission (or list of permissions) are
  present in a permissions field for the current user.

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


  The `{:permission, perms}` policy gets a permissions list from the `:current_user` field that
  has already been assigned. I am assuming that the policy `:current_user` is enforced before
  this one, so that fails, the `{:permission, perms}` policy won't be called.

  This is the one of the most complex policies I use. By passing in `{:permission, perms}`
  to identify the policy, I rely on Elixir to match on the `:permission` atom. I can then pass
  additional data through the `perms` term.

  This policy is typically enforced like this:

        plug MyAppWeb.Policies, {:permission, "dashboard"}
        # or
        plug MyAppWeb.Policies, {:permission, ["dashboard", "premium"]}


  **Note**: when you attach permissions to a user record in you DB, *please* use something
  like [Cloak](https://hex.pm/packages/cloak) to encrypt those values.

  # Return Values

  Policies return either :ok (indicating success) or {:error, message} (indicating failure).

  When being enforced via a plug, return :ok allows the plug chain to continue unchanged.

  Returning `{:error, message}` halts the plug chain and sends the message to your `policy_error`
  function. This is where you can choose how to handle the error. Perhaps by redirecting,
  signing the user out, or some other action.


  ## Use outside the plug chain

  Policies are usually enforced through a plug, but can also be used to decide if a user has
  permission to see a piece of UI or can use some other functionality.

  In a template:

        <%= if MyAppWeb.Policies.authorized?(@conn, {:admin_permission, "dashboard"}) do %>
          <%= link "Admin Dashboard", to: admin_dashboard_path(@conn, :index) %>
        <% end %>

  In an action in a controller:

        def settings(conn, params) do
          ...
          # raise an error if the current user is not the user specified in the url.
          MyAppWeb.Policies.enforce!(conn, :user_is_self)
          ...
        end
   

  ## Policies in a single controller

  Sometimes you want to enforce a policy just across the actions of a single controller. Instead
  of building up a separate policy module, you can just add and enforce the policy in the
  controller itself.

        defmodule MyAppWeb.Controller.AdminController do
          use PolicyWonk.Policy         # set up support for policies
          # do not need to use PolicyWonk.Enforce here...

          plug :enforce, :is_admin

          def policy( assigns, :is_admin ) do
            # something that checks if the current user is an admin...
          end

          def policy_error(conn, :current_user) do
            MyAppWeb.ErrorHandlers.unauthorized(conn)
          end
        end



  ## Policy Failures

  Policies return `{:error, message}` to indicate a policy failure. If called as a plug, this
  will halt the plug chain and send the `message` to your `policy_error` function, which is where
  you choose how to handle the error.

  You should define at least one `policy_error` function in same place you put your policies.

  Example:

        def policy_error(conn, err_data) do
          conn
          |> put_flash(:error, "Unauthorized")
          |> redirect(to: session_path(conn, :new))
        end

  The `policy_error` function looks like a regular plug function. It takes a `conn`, and
  whatever was returned from the policy. You can manipulate the `conn` however you want to respond
  to the error. It must return the transformed `conn`.

  Since the policy failed, the `Enforce` plug will make sure `Plug.Conn.halt(conn)` is called.

  """

  @doc """
  Define a policy. Accepts a map of resources and a policy identifier.

  When called by the `PolicyWonk.Enforce` or `PolicyWonk.EnforceAction` plugs, the map will be the assigns field from the current conn.

  Must either `:ok`, or `{:error, message}`. In the event of an error, the message term will be
  passed to your policy_error callback.

  ## Parameters
  * `assigns` The first parameter is the current assigns on the Plug.Conn object.
  * `identifier` The second is any term you want to either identify the policy or pass data.
  """
  @callback policy(assigns :: Map.t(), identifier :: any) :: :ok | {:error, any}

  @doc """
  Handle a failed policy. Only called during the plug chain.

  Must return a conn, which you are free to transform.

  ## Parameters
  * `conn` The first parameter is the current Plug.Conn object. Transform this conn to handle
  the specific error case.
  * `message` The second is is the error message term returned from your policy.
  """

  @callback policy_error(conn :: Plug.Conn.t(), message :: any) :: Plug.Conn.t()

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
      @doc """
      Callable as a local plug. Enforce accepts the current conn and a policy indicator.
      It then calls the policy, evaluates the response and either passes or transforms
      the conn with a failure.

      You will normally only use this function if you want to enforce a policy that is
      written into a controller. Then the plug call will look like this:

            plug :enforce, :some_policy


      If you want to enforce a policy from your router, please read the `PolicyWonk.Enforce`
      documentation.

      ## Parameters
      * `conn` The current conn in the plug chain
      * `policy` The policy or policies you want to enforce. This can be either a single
      term representing one policy, or a list of policy terms.
      """
      def enforce(conn, policies) do
        PolicyWonk.Policy.enforce(conn, __MODULE__, policies)
      end

      # ----------------------------------------------------
      @doc """
      Evaluates one or more policies and either returns :ok (success) or raises an error.

      This is useful for enforcing a policy within an action in a controller.

      ## Parameters
      * `conn` The current conn in the plug chain
      * `policy` The policy or policies you want to enforce. This can be either a single
      term representing one policy, or a list of policy terms.
      """
      def enforce!(conn, policies) do
        PolicyWonk.Policy.enforce!(conn, __MODULE__, policies)
      end

      # ----------------------------------------------------
      @doc """
      Evaluates one or more policies and either returns `true` (success) or `false` (failure).

      This is useful for choosing whether or not to render portions of a template, or for
      conditional logic in a controller.

      ## Parameters
      * `conn` The current conn in the plug chain
      * `policy` The policy or policies you want to enforce. This can be either a single
      term representing one policy, or a list of policy terms.
      """
      def authorized?(conn, policies) do
        PolicyWonk.Policy.authorized?(conn, __MODULE__, policies)
      end
    end

    # quote
  end

  # defmacro

  # ===========================================================================
  # internal functions from here down

  # ----------------------------------------------------
  # Enforce called as a (internal) plug
  @doc false
  def enforce(conn, module, policies)

  # don't do anything if the conn is already halted
  @doc false
  def enforce(%Plug.Conn{halted: true} = conn, _, _), do: conn

  # enforce a list of policies
  @doc false
  def enforce(%Plug.Conn{} = conn, module, policies) when is_list(policies) do
    Enum.reduce(policies, conn, &enforce(&2, module, &1))
  end

  # enforce a single policy
  @doc false
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
  @doc false
  def enforce!(conn, module, policies)

  # enforce! a list of policies
  @doc false
  def enforce!(%Plug.Conn{} = conn, module, policies) when is_list(policies) do
    Enum.each(policies, &enforce!(conn, module, &1))
  end

  # enforce! a single policies
  @doc false
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
  @doc false
  def authorized?(conn, module, policies)

  # enforce? that a list of policies pass
  @doc false
  def authorized?(%Plug.Conn{} = conn, module, policies) when is_list(policies) do
    Enum.all?(policies, &authorized?(conn, module, &1))
  end

  # enforce? a single policy
  @doc false
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
