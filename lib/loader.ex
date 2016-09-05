defmodule PolicyWonk.Loader do
  alias PolicyWonk.Utils


  @callback load_resource(Plug.Conn.t, atom, Map.t) :: {:ok, any} | {:error, any}
  @callback load_error(Plug.Conn.t, any) :: Plug.Conn.t


  @config_loaders Application.get_env(:policy_wonk, PolicyWonk)[:loaders]
  @config_async   Application.get_env(:policy_wonk, PolicyWonk)[:load_async]



  #===========================================================================
  # define a policy error here - not found or something like that
  defexception [message: "#{IO.ANSI.red}Unable to execute a loader\n"]


  #===========================================================================
  def init(%{loaders: loaders} = opts) when is_list(loaders) do
    async = case Map.fetch(opts, :async) do
      {:ok, async} -> async
      _ -> @config_async
    end

    %{
      loaders: Enum.uniq( loaders ),
      handler: opts[:handler],
      async:  async
    }
  end
  def init(%{loaders: loader} = opts), do: init( Map.put(opts, :loaders, [loader]) )
  def init(loaders) when is_list(loaders), do: init( %{loaders: loaders} )
  def init(loader), do: init( %{loaders: [loader]} )


  #----------------------------------------------------------------------------
  def call(conn, opts) do
    # figure out what handler to use
    handler = opts.handler ||
      Utils.controller_module(conn) ||
      Utils.router_module(conn)

    handlers = []
      |> Utils.append_truthy( handler )
      |> Utils.append_truthy( @config_loaders )

    # evaluate the policies. Cal error func if any fail
    if opts.async do
      # load the resources asynchronously
      async_loader(handlers, conn, opts.loaders)
    else
      # load the resources synchronously
      sync_loader(handlers, conn, opts.loaders)
    end
  end # def call


  #----------------------------------------------------------------------------
  defp async_loader(handlers, conn, loaders) do
    # spin up tasks for all the loads
    load_tasks = Enum.map(loaders, fn(loader) ->
      {loader, Task.async( fn -> call_loader(handlers, conn, loader) end)}
    end)

    # wait for the async tasks to complete - assigning each into the conn
    Enum.reduce_while( load_tasks, conn, fn ({loader, task}, acc_conn )->
      case Task.await(task) do
        {:ok, resource} ->
          {:cont, Plug.Conn.assign(acc_conn, loader, resource)}
        {:error, err_data} ->
          {:halt, call_loader_error(handlers, conn, err_data)}
        _ ->
          raise "load_resource must return either {:ok, resource} or {:error, err_data}"
      end
    end)
  end

  #----------------------------------------------------------------------------
  defp sync_loader(handlers, conn, loaders) do
    Enum.reduce_while( loaders, conn, fn (loader, acc_conn )->
      case call_loader(handlers, acc_conn, loader) do
        {:ok, resource} ->
          {:cont, Plug.Conn.assign(acc_conn, loader, resource)}
        {:error, err_data} ->
          {:halt, call_loader_error(handlers, acc_conn, err_data)}
        _ ->
          raise "load_resource must return either {:ok, resource} or {:error, err_data}"
      end
    end)
  end


  #----------------------------------------------------------------------------
  defp call_loader( handlers, conn, loader ) do
    try do
      Utils.call_down_list(handlers, fn(handler) ->
        handler.load_resource(conn, loader, conn.params)
      end)
    catch
      # if a match wasn't found on the module, try the next in the list
      :not_found ->
        # load_resource wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}load_resource#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}Params: #{IO.ANSI.yellow}#{inspect(conn.params)}\n" <>
          "#{IO.ANSI.green}Loader: #{IO.ANSI.yellow}#{inspect(loader)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.Policy{ message: msg }
    end
  end

  #----------------------------------------------------------------------------
  defp call_loader_error(handlers, conn, err_data ) do
    try do
      Utils.call_down_list(handlers, fn(handler) ->
        handler.load_error(conn, err_data)
      end)
    catch
      # if a match wasn't found on the module, try the next in the list
      :not_found ->
        # load_error wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}load_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.Policy{ message: msg }
    end
  end

end