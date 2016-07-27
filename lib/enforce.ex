defmodule PolicyWonk.Enforce do

  @route_policies Application.get_env(:policy_wonk, PolicyWonk)[:route_policies]
  @error_handler  Application.get_env(:policy_wonk, PolicyWonk)[:error_handler]

  #----------------------------------------------------------------------------
  def init(opts) when is_map(opts) do
    # explicitly copy map options over. reduces to just the ones I know.
    %{
      policies:       opts[:policies],
      handler:        opts[:handler],
      error_handler:  opts[:error_handler] || @error_handler
    }
  end
  def init(opts) when is_list(opts) do
    # incoming opts is a list of resources. prep/filter list, and pass back in a map
    # opts must be a list of strings or atoms...
    %{
      policies:       opts,
      handler:        nil,
      error_handler:  @error_handler
    }
  end
  def init(opts), do: init( [opts] )


  #----------------------------------------------------------------------------
  # if a handler is requested, use that.
  # if no handler is set, use the controller
  # if no controller is set (stil in the router), use the router
  def call(conn, opts) do
    # get the correct module to handle the policies
    handler = opts[:policy_handler] ||
      conn.private[:phoenix_controller] ||
      @route_policies ||
      conn.private[:phoenix_router]
    unless handler do
      raise "unable to find a policy module"
    end

    # get the list of policies to test. action is added if available
    policy_list = if conn.private[:phoenix_action] do
      opts[:policies] ++ [conn.private.phoenix_action]
    else
      opts[:policies]
    end

    # Enumerate through all the policies. Fail if any fail
    Enum.reduce_while( policy_list, conn, fn(policy, acc_conn) ->
      case handler.policy( acc_conn, policy ) do
        {:ok, policy_conn = %Plug.Conn{} }    ->
          {:cont, policy_conn}
        { _err, policy_conn  = %Plug.Conn{} } ->
          {:halt, Plug.Conn.halt(policy_conn) }
        _ -> raise "malformed policy response"
      end
    end)
  end # def call

end
