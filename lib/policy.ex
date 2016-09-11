defmodule PolicyWonk.Policy do


  use Behaviour

  #@callback policy(Plug.Conn.t, any) :: :ok | any

  @doc """
  Defines a policy. Accepts a map of resources and a policy identifier. Returns either `:ok`, or
  error information that is passed to your `policy_error` function.

  When your policy is called by either the Enforce or EnforceAction plugs, the first parameter
  will be %Plug.Conn{} that is flowing through the plug chain. If you are evaluating the policy your.
  It is by design that the policy cannot change the conn map. It either succeeds, or fails with error
  data that you can interpret in the policy_error function.

  ### Examples

  These are the two policies I use most...

  Remember that the ONLY response indicating success is the atom :ok. Anthing
  else is interpreted as a failure and passed to the policy_error function.

      # policy to ensure any user is signed in
      def policy( assigns, :current_user ) do
        case assigns[:current_user] do
          _user = %Loom.Account.User{} -> :ok     # success
          _ ->    :current_user                   # failure
        end
      end

      # policy to make sure a user has the given permissions in an array of
      # permission strings stored on the current_user
      # assumes user.permissions is an array of strings
      def policy( assigns, {:user_perm, perms} ) when is_list(perms) do
        user = assigns.current_user
        case user.permissions do
          nil -> {:user_perm, perms}              # failure
          user_perms ->
            Enum.all?(perms, fn(p) -> Enum.member?(user_perms, to_string(p)) end)
            |> case do
              true -> :ok                         # success!
              false -> {:user_perm, perms}        # failure
            end
        end
      end
      def policy( assigns, {:user_perm, one_perm} ), do:
        policy( assigns, {:user_perm, [one_perm]} )


  """

  defcallback policy(Map.t, any) :: :ok | any




  #@callback policy_error(Plug.Conn.t, any) :: Plug.Conn.t
  defcallback policy_error(Plug.Conn.t, any) :: Plug.Conn.t

end