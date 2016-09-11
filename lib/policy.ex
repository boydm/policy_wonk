defmodule PolicyWonk.Policy do
  use Behaviour

@moduledoc """

To keep authorization logic organized, PolicyWonk uses policy functions that you create either in your controllers, router, or a central location.

A policy is a function that makes a simple yes/no decision.

      # ensure a user is signed in
      def policy( assigns, :current_user ) do
        case assigns[:current_user] do
          _user = %MyApp.User{} -> :ok
          _ ->    :current_user
        end
      end
 
The *only* way to indicate success from a policy is to return the atom `:ok`. Anything else is a policy failure. (see below)

The first parameter `Map` of the resources being evaluated. When called by a plug, this is the assigns map from the current `%Plug.Conn{}`. The second parameter is the policy data you specified when using the PolicyWonk.Enforce plug. If you used EnforceAction, then the second parameter is simply the atom representing the current action.

The idea is that you define multiple policy functions and use Elixir’s pattern matching to find the right one. If you use a tuple (or a map) as the second parameter, then you can have more complex calls to your policies.

      def policy( assigns, {:user_permission, perms} ) when is_list(perms) do
        case assigns.current_user.permissions do
          nil -> {:user_perm, perms}        # Fail. No permissions
          user_perms ->
            Enum.all?(perms, fn(p) -> Enum.member?(user_perms, to_string(p)) end)
            |> case do
              true -> :ok                   # Success.
              false -> {:user_perm, perms}  # Fail. Permission missing
            end
        end
      end
      def policy( assigns, {:user_permission, one_perm} ), do:
        policy( assigns, {:user_perm, [one_perm]} )


The policy `{:user_permission, perms}` is the most complex individual policy I use. The first element of the incoming type is an atom to allow Elixir to pattern match to right function. The second element is a list of strings that should be present on the user’s permissions field. 

Since I use the `{:user_permission, perms}` policy on multiple controllers (and the router!) I keep it in a central `lib/policy_wonk/policies.ex` file, which I point to in the configuration data.

**Note**: when you attach permissions to a user record in you DB, *please* use something like [Cloak](https://hex.pm/packages/cloak) to encrypt those values.

## Use outside the plug chain
Policies are usually called from one of the enforce plugs, but can also be used to decide if a user has permission to see a piece of UI and some other thing.

You can evaluate policies within templates, actions, and other code by using the `authorized?` function. See documentation for `PolicyWonk.Enforce` for details.
 
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

You can also specify the policy’s module when you invoke the `PolicyWonk.Enforce` or `PolicyWonk.EnforceAction` plugs. This will be the only module the plug looks for a policy in.

"""



  @doc """
  Define a policy. Accepts a map of resources and a policy identifier.

  When called by the `PolicyWonk.Enforce` or `PolicyWonk.EnforceAction` plugs, the map will be the assigns field from the current conn.

  Returns either `:ok`, or error_data that is passed to your `policy_error` function.
  """
  defcallback policy(Map.t, any) :: :ok | any



  @doc """
  Handle a failed policy. Called during the plug chain.

  The second parameter is whatever was returned from your `policy` function other than :ok.

  Must return a conn, which you are free to transform.
  """

  defcallback policy_error(Plug.Conn.t, any) :: Plug.Conn.t

end