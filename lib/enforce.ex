defmodule PolicyWonk.Enforce do
  alias PolicyWonk.Utils

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
      |> Utils.append_truthy( opts[:policy_handler] )
      |> Utils.append_truthy( Utils.get_exists(conn, [:private, :phoenix_controller]) )
      |> Utils.append_truthy( @config_policies )
      |> Utils.append_truthy( Utils.get_exists(conn, [:private, :phoenix_router]) )
    if handlers == [] do
      raise %PolicyWonk.Enforce.Error{message: "No policy modules set"}
    end

    # Enumerate through all the policies. Fail if any fail
    Enum.reduce_while( opts.policies, conn, fn(policy, acc_conn) ->
      case call_policy( handlers, acc_conn, policy ) do
        {:ok, conn} ->
          {:cont, conn}
        {:err, conn, err_data} ->
          {:halt, call_policy_error( handlers, conn, err_data ) }
      end
    end)
  end # def call


  #----------------------------------------------------------------------------
  def call_policy( handlers, conn, policy ) do
    Utils.call_into_list(handlers, fn(handler) ->
      handler.policy(conn, policy)
    end)
    |> case do
      :not_found ->
        # policy wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}policy#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}Policy: #{IO.ANSI.yellow}#{inspect(policy)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.Enforce.Error{ message: msg }
      :ok ->                                {:ok, conn}
      true ->                               {:ok, conn}
      false ->                              {:err, conn, nil}
      :err ->                               {:err, conn, nil}
      :error ->                             {:err, conn, nil}
      {:ok, policy_conn = %Plug.Conn{}} ->  {:ok, policy_conn}
      {:err, err_data} ->                   {:err, conn, err_data}
      _ ->                                  raise "malformed policy response"
    end
  end

  #----------------------------------------------------------------------------
  def call_policy_error( handlers, conn, err_data ) do
    Utils.call_into_list(handlers, fn(handler) ->
      handler.policy_error(conn, err_data )
    end)
    |> case do
      :not_found ->
        # policy_error wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}policy_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.Enforce.Error{ message: msg }
      conn = %Plug.Conn{} ->  conn
      _ -> raise              "policy_error must return a conn"
    end
  end

end