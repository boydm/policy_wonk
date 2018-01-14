defmodule PolicyWonk.LoadResource do
  alias PolicyWonk.Utils

@moduledoc """

This the resource loading plug.

## Loading Resources

In order to evaluate policies, you need to have resources loaded into memory first.

In a plug stack, code is run before your controller’s actions, so you need to use `PolicyWonk.LoadResource` (or equivalent) to load resources into the conn’s `assigns` field before running the `PolicyWonk.Enforce` plug.

In a controller…

    plug PolicyWonk.LoadResource, :thing_a
    
In a router…

    pipeline :browser_session do
      plug PolicyWonk.LoadResource, :current_user
    end

The result is that your `:current_user` loader function is called. If it succeeds, it returns a resource (assumedly the current user…), which `PolicyWonk.LoadResource` adds to the conn’s `assigns` field

Please see documentation for `PolicyWonk.Loader` to see how to implement your loaders.

## Specifying Loaders

The main parameter to the `PolicyWonk.LoadResource` plug is either a single resource or a list of resources to load.

      plug PolicyWonk.LoadResource, :thing_a
      plug PolicyWonk.LoadResource, [:thing_a, :thing_b]

The “name” of the resource can be pretty much any type you want to pass in to your policy. It doesn’t need to be an atom, although that is very convenient to match on.

If you specify a list of things to load, then they will each be loaded and added to the plug’s `assigns` field.

These are all valid resource specifiers:

      plug PolicyWonk.LoadResource, [:thing_a, :thing_b]
      plug PolicyWonk.LoadResource, {:thing_s, "a string")
      plug PolicyWonk.LoadResource, %{id: "an_id", data: %{color: "blue"}}

The idea is that you create matching `load_resource` functions and rely Elixir’s function matching to select the right one.

      def load_resource( _conn, :thing_a, _assigns ) do
        {:ok, :thing_a, "data goes here"}
      end
      
      def load_resource( _conn, {:thing_s, name}, _assigns ) do
        {:ok, :thing_name, name}
      end

## Resource Assignment

When your `load_resource` function succeeds, it should return a tuple in the form of:

`{:ok, :resource_name, resource}`.
* `:ok` indicates the load succeeded
* `:resource_name` is any atom you choose to represent the name of the resource. The resource will be added to the conn’s `assigns` field with this name.
* `resource` this is the loaded resource itself

In other words, if you return the tuple `{:ok, :name,"policy_wonk"}`, then when `PolicyWonk.LoadResource` is finished doing it’s work, `conn.assigns.name` will be `"policy_wonk"`.

You do not directly add the resource to the conn’s `assigns` field yourself in order to facilitate asynchronous loading. (below)

## Synchronous vs. Asynchronous loading

One of my favorite parts of working with Elixir is the ease of writing parallel, asynchronous code. Loading a resource from a database, generating hashes, or other operations can often take a measurable amount of time to complete, even though they are not necessarily compute intensive.

If you load all the resources a given web page is going to use one after the other, you will dramatically increase your response times.

`PolicyWonk.LoadResource` helps by (optionally) loading the resources you specify in any given call asynchronously.

    plug PolicyWonk.LoadResource, [:thing_a, :thing_b]

In this case, both `:thing_a` and `:thing_b` are going to hit the database. If the PolicyWonk config block has set load_async to `true`, then they will be loaded in parallel, saving significant time.

You can also request asynchronous loading with the expanded form of the plug invocation.

    plug PolicyWonk.LoadResource, %{resources: [:thing_a, :thing_b], async: true}

## Use with Guards

When the `PolicyWonk.LoadResource` is invoked inside a Phoenix controller, you can add guards against the current action.

    plug PolicyWonk.LoadResource, :thing_a when action in [:index]


## Handling Load Failures

If any call to a `load_resource` function fails, then the `PolicyWonk.LoadResource` plug calls your `load_error` function with the data returned by the loader.

This is where you transform the conn to handle the error gracefully.

Unlike policies, not every resource failure should halt the plug stack, so calling `Plug.Conn.halt(conn)` is up to you to do in your `load_error` function.

## Specifying the Loader Module

As discussed in [the documentation for PolicyWonk.Loader](PolicyWonk.Loader.html#module-loader-locations), 
the `PolicyWonk.LoadResource` plug will look for loaders first in your controller (or router) as appropriate. Then in the module/s specified in the config block.

If you are using the plug outside phoenix, then just the config block is checked.

You can also specify exactly which module to look in at the time you invoke the plug.

    plug PolicyWonk.LoadResource, %{resources: [:thing_1], module: MyLoaderModule}

If you do specify the module, then that is the only one `PolicyWonk.Enforce` will look in for loaders.

"""

  @default_otp_app      :policy_wonk


  #===========================================================================
  # define a policy error here - not found or something like that
  defmodule ResourceError do
    @moduledoc false
    defexception [message: "#{IO.ANSI.red}Unable to execute a resource\n"]
  end


  #===========================================================================
  # the using macro for loaders adopting this behavioiur
  defmacro __using__(use_opts) do
    quote do
      @otp_app    unquote(use_opts[:otp_app])

      @behaviour    PolicyWonk.Loader

      def init( opts ),     do: PolicyWonk.LoadResource.do_init( opts, otp_app: @otp_app )
      def call(conn, opts), do: PolicyWonk.LoadResource.call(conn, opts)
    end # quote
  end # defmacro


  #===========================================================================
  @doc """
  Initialize an invocation of the plug.
  
  [See the discussion of specifying loaders above.](PolicyWonk.LoadResource.html#module-specifying-loaders)
  """
  def init(%{resources: resources} = opts) when is_list(resources) do
    otp_app = opts[:otp_app] || @default_otp_app

    async = case Map.fetch(opts, :async) do
      {:ok, async} -> async
      _ -> config_async()
    end

    %{
      resources: Enum.uniq( resources ),
      module: opts[:module],
      async: async,
      otp_app: otp_app
    }
  end
  def init(%{resources: resource} = opts), do: init( Map.put(opts, :resources, [resource]) )
  def init(resources) when is_list(resources), do: init( %{resources: resources} )
  def init(resource), do: init( %{resources: [resource], async: false} )
















  #--------------------------------------------------------
  # next time... offer fewer choices on how to format the options. would make this easier
  @doc false
  def do_init(res_opts, opts) when is_map(res_opts),  do: init( Map.put(res_opts, :otp_app, opts[:otp_app]) )
  def do_init(ress, opts) when is_list(ress),         do: init( %{resources: ress, otp_app: opts[:otp_app]} )
  def do_init(res, opts), do: init( %{resources: [res], async: false, otp_app: opts[:otp_app]} )


  #----------------------------------------------------------------------------
  @doc """
  Call is used by the plug stack. 
  """
  def call(conn, opts) do
    # figure out what module to use
    module = opts.module ||
      Utils.controller_module(conn) ||
      Utils.router_module(conn)

    modules = []
      |> Utils.append_truthy( module )
      |> Utils.append_truthy( config_loaders() )

    # evaluate the policies. Cal error func if any fail
    if opts.async do
      # load the resources asynchronously
      async_load(modules, conn, opts.resources)
    else
      # load the resources synchronously
      sync_load(modules, conn, opts.resources)
    end
  end # def call


  #----------------------------------------------------------------------------
  defp async_load(modules, conn, resources) do
    # spin up tasks for all the loads
    load_tasks = Enum.map(resources, fn(resource) ->
      Task.async( fn -> call_loader(modules, conn, resource) end)
    end)

    # wait for the async tasks to complete - assigning each into the conn
    Enum.reduce_while( load_tasks, conn, fn (task, acc_conn )->
      assign_resource(
        Task.await(task),
        acc_conn,
        modules
      )
    end)
  end

  #----------------------------------------------------------------------------
  defp sync_load(modules, conn, resources) do
    Enum.reduce_while( resources, conn, fn (resource, acc_conn )->
      assign_resource(
        call_loader(modules, acc_conn, resource),
        acc_conn,
        modules
      )
    end)
  end

  #----------------------------------------------------------------------------
  defp assign_resource(result, conn, modules) do
    case result do
      {:ok, name, resource} when is_atom(name) ->
        {:cont, Plug.Conn.assign(conn, name, resource)}
      err_data ->
        {:halt, call_loader_error(modules, conn, err_data)}
#      _ ->
#        msg = "#{IO.ANSI.red}load_resource must return either {:ok, :resource_name, resource} or err_data\n" <>
#          "#{IO.ANSI.green}conn.params: #{IO.ANSI.yellow}#{inspect(conn.params)}\n" <>
#          "#{IO.ANSI.green}resource: #{IO.ANSI.yellow}#{inspect(resource)}\n"
#        raise %PolicyWonk.LoadResource.ResourceError{ message: msg }
    end
  end


  #----------------------------------------------------------------------------
  defp call_loader( modules, conn, resource ) do
    try do
      Utils.call_down_list(modules, {:load_resource, [conn, resource, conn.params]})
    catch
      # if a match wasn't found on the module, try the next in the list
      :not_found ->
        # load_resource wasn't found on any module. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}load_resource#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}conn.params: #{IO.ANSI.yellow}#{inspect(conn.params)}\n" <>
          "#{IO.ANSI.green}resource: #{IO.ANSI.yellow}#{inspect(resource)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_modules_msg( modules ) <>
          IO.ANSI.red
        raise %PolicyWonk.LoadResource.ResourceError{ message: msg }
    end
  end

  #----------------------------------------------------------------------------
  defp call_loader_error(modules, conn, err_data ) do
    try do
      Utils.call_down_list(modules, {:load_error, [conn, err_data]})
    catch
      # if a match wasn't found on the module, try the next in the list
      :not_found ->
        # load_error wasn't found on any module. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}load_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_modules_msg( modules ) <>
          IO.ANSI.red
        raise %PolicyWonk.LoadResource.ResourceError{ message: msg }
    end
  end

  defp config_loaders do
    Application.get_env(:policy_wonk, PolicyWonk)[:loaders]
  end

  defp config_async do
    Application.get_env(:policy_wonk, PolicyWonk)[:load_async]
  end

end
