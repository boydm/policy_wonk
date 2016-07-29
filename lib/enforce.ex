defmodule PolicyWonk.Enforce do

  @config_policies Application.get_env(:policy_wonk, PolicyWonk)[:policy_modules]

  # define a policy error here - not found or something like that
  defmodule PolicyError do
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
      |> append_truthy( opts[:policy_handler] )
      |> append_truthy( conn.private[:phoenix_controller] )
      |> append_truthy( @config_policies )
      |> append_truthy( conn.private[:phoenix_router] )
    if handlers == [] do
      raise %PolicyError{message: "No policy modules set"}
    end

    # Enumerate through all the policies. Fail if any fail
    Enum.reduce_while( opts.policies, conn, fn(policy, acc_conn) ->
      call_policy( handlers, acc_conn, policy )
    end)
  end # def call

  #----------------------------------------------------------------------------
  defp call_policy( handlers, conn, policy ) do
    # try to call the policy on each handler until one that
    # has the right signature is found

    #find(enumerable, default \\ nil, fun)
    # use default of :not_found, so I can tell if the function wasn't
    # found on any of the handlers
    Enum.find_value(handlers, :not_found, fn(handler) ->
      case handler do
        nil -> false  # empty spot in the handler list
        h ->
          try do
            case h.policy( conn, policy ) do
              :ok ->    {:cont, conn}
              true ->   {:cont, conn}
              false ->  {:halt, handle_error( conn, nil, handler )}
              {:ok, policy_conn = %Plug.Conn{}} ->
                {:halt, {:cont, policy_conn}}
              {:err, err_data} ->
                {:halt, handle_error( handlers, conn, err_data ) }
              _ -> raise "malformed policy response"
            end
          rescue
            _e in UndefinedFunctionError ->
              # tried to call policy, but the function wasn't defined
              # on the handler. Return false so that find_value will
              # try the next handler in the list
              false
            _e in FunctionClauseError -> false
            e ->
              # some other error. let it raise
              raise e
          end
      end
    end)
    |> case do
      :not_found ->
        # The policy wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable to a #{IO.ANSI.yellow}policy#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}Policy: #{IO.ANSI.yellow}#{inspect(policy)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Enum.reduce(handlers, "", fn(h, acc) ->
            case h do
              nil -> acc
              mod -> acc <> inspect(mod) <> "\n"
            end
          end) <>
          IO.ANSI.red
        raise %PolicyError{ message: msg }
      response -> response
    end
  end

  #----------------------------------------------------------------------------
  # similar to call_policy
  defp handle_error( handlers, conn, err_data ) do
    Enum.find_value(handlers, :not_found, fn(handler) ->
      case handler do
        nil -> false  # empty spot in the handler list
        h ->
          try do
            case h.policy_error(conn, err_data ) do
              conn = %Plug.Conn{} ->
                conn
              _ ->
                raise "policy_error must return a conn"
            end
          rescue
            _e in UndefinedFunctionError ->
              # tried to call policy_error, but the function wasn't defined
              # on the handler. Return false so that find_value will
              # try the next handler in the list
              false
            _e in FunctionClauseError -> false
            e ->
              # some other error. let it raise
              raise e
          end
      end
    end)
    |> case do
      :not_found ->
        # The policy wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable to a #{IO.ANSI.yellow}policy_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Enum.reduce(handlers, "", fn(h, acc) ->
            case h do
              nil -> acc
              mod -> acc <> inspect(mod) <> "\n"
            end
          end)
        raise %PolicyError{ message: msg }

        # The policy wasn't found on any handler. raise an error
        raise "policy not found on any handlers"
      response -> response
    end
  end

  #----------------------------------------------------------------------------
  defp append_truthy(list, element) when is_list(list) do
    cond do
      is_list(element) -> list ++ element
      element -> list ++ [element]
      true -> list
    end
  end


end



