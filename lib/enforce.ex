defmodule PolicyWonk.Enforce do

  @config_policies Application.get_env(:policy_wonk, PolicyWonk)[:policy_modules]

  # define a policy error here - not found or something like that
  defmodule Error do
    defexception [message: "#{IO.ANSI.red}Unable to execute a policy\n"]
  end

  #----------------------------------------------------------------------------
  def init(opts) when is_map(opts) do
    # explicitly copy map options over. reduces to just the ones I know.
    %{
      policies:       opts[:policies],
      handler:        opts[:handler]
    }
  end
  def init(opts) when is_list(opts) do
    # incoming opts is a list of resources. prep/filter list, and pass back in a map
    # opts must be a list of strings or atoms...
    %{
      policies:       opts,
      handler:        nil
    }
  end
  def init(opts), do: init( [opts] )


  #----------------------------------------------------------------------------
  # if a handler is requested, use that.
  # if no handler is set, use the controller
  # if no controller is set (stil in the router), use the router
  def call(conn, opts) do
    # get the policy handling modules
    handlers = []
      |> PolicyWonk.Utils.append_truthy( opts[:policy_handler] )
      |> PolicyWonk.Utils.append_truthy( conn.private[:phoenix_controller] )
      |> PolicyWonk.Utils.append_truthy( @config_policies )
      |> PolicyWonk.Utils.append_truthy( conn.private[:phoenix_router] )
    if handlers == [] do
      raise %PolicyWonk.Enforce.Error{message: "No policy modules set"}
    end

    # Enumerate through all the policies. Fail if any fail
    Enum.reduce_while( opts.policies, conn, fn(policy, acc_conn) ->
      case PolicyWonk.Utils.call_policy( handlers, acc_conn, policy ) do
        {:ok, conn} ->
          {:cont, conn}
        {:err, conn, err_data} ->
          {:halt, PolicyWonk.Utils.call_policy_error( handlers, conn, err_data ) }
      end
    end)
  end # def call

end