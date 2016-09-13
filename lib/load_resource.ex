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

The result is that your `:current_user` resource function is called. If it succeeds, it returns a resource (assumedly the current user…), which `PolicyWonk.LoadResource` adds to the conn’s `assigns` field

Please see documentation for `PolicyWonk.resource` to see how to implement your resources.

## Specifying resources

The main parameter to the `PolicyWonk.LoadResource` plug is either a single resource or a list of resources to load.

      plug PolicyWonk.LoadResource, :thing_a
      plug PolicyWonk.LoadResource, [:thing_a, :thing_b]

The “name” of the resource can be pretty much any type you want to pass in to your policy. It doesn’t need to be an atom, although that is very conveninent to match on.

If you specify a list of things to load, then they will each be loaded and added to the plug’s `assigns` field.

These are all valid resource specifiers:

      plug PolicyWonk.LoadResource, [:thing_a, :thing_b]
      plug PolicyWonk.LoadResource, {:thing_s, "a string")
      plug PolicyWonk.LoadResource, %{id: "an_id", data: %{color: "blue"}}

The idea is that you create matching `load_resource` functions and rely Elixir’s function matching to select the right one.

      def load_resource( assigns, :thing_a ) do
        {:ok, :thing_a, "data goes here"}
      end
      
      def load_resource( assigns, {:thing_s, name} ) do
        {:ok, :thing_name, name}
      end

## Resource Assignment

When your `load_resource` function succeeds, it returns a tuple in the form of:

`{:ok, :resource_name, resource}`.
* `:ok` indicates the load succeeded
* `:resource_name` is any atom you choose to represent the name of the resource. The resource will be added to the conn’s assigns field with this name.
* `resource` this is the loaded resource itself

In other words, if you return the tuple `{:ok, :name,"policy_wonk"}`, then when `PolicyWonk.LoadResource` is finished doing it’s work, `conn.assigns.name` will be `"policy_wonk"`.

You do not directly add the resource to the conn’s `assigns` field yourself in order to facilitate asyncronous loading. (below)

## Synchronous vs. Asynchronous loading


## Use with Guards

When the `PolicyWonk.LoadResource` is invoked inside a Phoenix controller, you can add guards against the current action.

    plug PolicyWonk.LoadResource, :thing_a when action in [:index]


## Handling Policy Failures

## Specifying the resource Module

"""


  @config_loaders Application.get_env(:policy_wonk, PolicyWonk)[:loaders]
  @config_async   Application.get_env(:policy_wonk, PolicyWonk)[:load_async]


  #===========================================================================
  # define a policy error here - not found or something like that
  defmodule ResourceError do
    defexception [message: "#{IO.ANSI.red}Unable to execute a resource\n"]
  end


  #===========================================================================
  def init(%{resources: resources} = opts) when is_list(resources) do
    async = case Map.fetch(opts, :async) do
      {:ok, async} -> async
      _ -> @config_async
    end

    %{
      resources: Enum.uniq( resources ),
      module: opts[:module],
      async:  async
    }
  end
  def init(%{resources: resource} = opts), do: init( Map.put(opts, :resources, [resource]) )
  def init(resources) when is_list(resources), do: init( %{resources: resources} )
  def init(resource), do: init( %{resources: [resource], async: false} )


  #----------------------------------------------------------------------------
  def call(conn, opts) do
    # figure out what module to use
    module = opts.module ||
      Utils.controller_module(conn) ||
      Utils.router_module(conn)

    modules = []
      |> Utils.append_truthy( module )
      |> Utils.append_truthy( @config_loaders )

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
      Utils.call_down_list(modules, fn(module) ->
        module.load_resource(conn, resource, conn.params)
      end)
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
      Utils.call_down_list(modules, fn(module) ->
        module.load_error(conn, err_data)
      end)
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

end