defmodule PolicyWonk.LoadResource do

  @config_loader  Application.get_env(:policy_wonk, PolicyWonk)[:loader]
  @load_async     Application.get_env(:policy_wonk, PolicyWonk)[:load_async]

  # define a policy error here - not found or something like that
  defmodule LoaderError do
    defexception [message: "#{IO.ANSI.red}Unable to execute a loader\n"]
  end

  #----------------------------------------------------------------------------
  def init(opts) when is_map(opts) do
    # explicitly copy map options over. reduces to just the ones I know.
    %{
      resource_list:  prep_resource_list( opts[:resources] ),
      loader:         opts[:loader],
      async:          opts[:async] || @load_async#,
      #error_handler:  opts[:error_handler] || @error_handler
    }
  end
  def init(opts) when is_list(opts) do
    # incoming opts is a list of resources. prep/filter list, and pass back in a map
    # opts must be a list of strings or atoms...
    %{
      resource_list:  prep_resource_list(opts),
      loader:         nil,
      async:          @load_async#,
      #error_handler:  @error_handler
    }
  end
  def init(opts) when is_bitstring(opts),  do: init( [String.to_atom(opts)] )
  def init(opts) when is_atom(opts),       do: init( [opts] )
  #--------------------------------------------------------
  defp prep_resource_list( list ) do
    case list do
      nil -> []
      list ->
        Enum.filter_map(list, fn(res) ->
            # the filter
            cond do
              is_bitstring(res) -> true
              is_atom(res)      -> true
              true              -> false    # all other types
            end
          end, fn(res) ->
            # the mapper
            cond do
              is_bitstring(res) -> String.to_atom(res)
              is_atom(res)      -> res
            end
          end)
    end
    |> Enum.uniq
  end


  #----------------------------------------------------------------------------
  def call(conn, opts) do
    # get the correct module to handle the policies. Use, in order...
      # the specified loader in opts
      # the controller, if one is set. Will be nil if in the router
      # the global loader set in config
      # the router itself
    loaders = []
      |> PolicyWonk.Utils.append_truthy( opts[:loader] )
      |> PolicyWonk.Utils.append_truthy( conn.private[:phoenix_controller] )
      |> PolicyWonk.Utils.append_truthy( @config_loader )
      |> PolicyWonk.Utils.append_truthy( conn.private[:phoenix_router] )
    if loaders == [] do
      raise %LoaderError{message: "No loader modules set"}
    end

    # load the resources. May be async
    cond do
      opts.async ->   async_loader(loaders, conn, opts)
      true ->         sync_loader(loaders, conn, opts)
    end
  end # def call

  #----------------------------------------------------------------------------
  defp async_loader(loaders, conn, opts) do
    # asynch version of the loader. use filter_map to build a list of loader
    # tasks that are only for non-already-loaded resources. Then wait for all
    # of those asynchronous tasks to complete. This is part of why I love Elixir

    # spin up tasks for all the loads
    res_tasks = Enum.filter_map( opts.resource_list, fn(res_type) ->
          # the filter
          conn.assigns[res_type] == nil
        end, fn(res_type) ->
          # the mapper
          task = Task.async( fn -> call_loader(loaders, conn, res_type, conn.params) end )
          {res_type, task}
        end)

    # wait for the async tasks to complete
    Enum.reduce_while( res_tasks, conn, fn ({res_type, task}, acc_conn )->
        assign_resource(
          loaders,
          acc_conn,
          res_type,
          Task.await(task)
        )
      end)
  end

  #----------------------------------------------------------------------------
  defp sync_loader(loaders, conn, opts) do
    # reject loading any resources already assigned into the conn
    # this is done by the filter_map in the async version
    Enum.reject(opts.resource_list, fn(r) -> conn.assigns[r] end)
    # load the remaining resources
    |> Enum.reduce_while( conn, fn (res_type, acc_conn )->
        assign_resource(
          loaders,
          acc_conn,
          res_type,
          call_loader(loaders, acc_conn, res_type, acc_conn.params)
        )
      end)
  end

  #----------------------------------------------------------------------------
  defp call_loader( loaders, conn, resource_id, params ) do
    # try to call the policy on each handler until one that
    # has the right signature is found

    #find(enumerable, default \\ nil, fun)
    # use default of :not_found, so I can tell if the function wasn't
    # found on any of the handlers
    Enum.find_value(loaders, :not_found, fn(loader) ->
      case loader do
        nil -> false  # empty spot in the handler list
        l ->
          try do
            l.load_resource( conn, resource_id, params )
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
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}load_resource#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}Loader: #{IO.ANSI.yellow}#{inspect(resource_id)}\n" <>
          "#{IO.ANSI.green}Params: #{IO.ANSI.yellow}#{inspect(conn.params)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Enum.reduce(loaders, "", fn(h, acc) ->
            case h do
              nil -> acc
              mod -> acc <> inspect(mod) <> "\n"
            end
          end) <>
          IO.ANSI.red
        raise %LoaderError{ message: msg }
      response -> response
    end
  end

  #----------------------------------------------------------------------------
  defp assign_resource(loaders, conn, resource_id, resource) do
    case resource do
      {:ok, resource} ->
        {:cont, Plug.Conn.assign(conn, resource_id, resource)}
      {:err, msg} ->
        handle_error(loaders, conn, msg)
      _ ->
        raise "load_resource must return either {:ok, resource} or {:err, message}"
    end
  end

  #----------------------------------------------------------------------------
  # similar to call_policy
  defp handle_error( loaders, conn, err_data ) do
    Enum.find_value(loaders, :not_found, fn(loader) ->
      case loader do
        nil -> false  # empty spot in the handler list
        l ->
          try do
            case l.load_error(conn, err_data ) do
              conn = %Plug.Conn{} ->
                {:halt, conn}
              _ ->
                raise "load_error must return a conn"
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
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}load_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Enum.reduce(loaders, "", fn(h, acc) ->
            case h do
              nil -> acc
              mod -> acc <> inspect(mod) <> "\n"
            end
          end)
        raise %LoaderError{ message: msg }
      response -> response
    end
  end

end









