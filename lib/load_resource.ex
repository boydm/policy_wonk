defmodule PolicyWonk.LoadResource do
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

  #===========================================================================
  # the using macro for loaders adopting this behavioiur
  defmacro __using__(use_opts) do
    quote do
      def init( resources_or_opts ) do
        case Keyword.keyword?(resources_or_opts) do
          true ->
            resources_or_opts
            |> Keyword.put_new( :resource_module, unquote(use_opts[:resource_module]) || __MODULE__ )
            |> Keyword.put_new( :async, unquote(use_opts[:async]) || false )
            |> PolicyWonk.LoadResource.init()
          false ->
            PolicyWonk.LoadResource.init(resource_module: __MODULE__, async: false, resources: resources_or_opts)
        end
      end

      def call(conn, opts), do: PolicyWonk.LoadResource.call(conn, opts)
    end # quote
  end # defmacro


  #===========================================================================
  # define a policy error here - not found or something like that
  defmodule Error do
    @moduledoc false
    defexception [message: "#{IO.ANSI.red}Load resource failed#{IO.ANSI.default_color()}\n"]
  end


  #===========================================================================
  @doc """
  Initialize an invocation of the plug.
  
  [See the discussion of specifying loaders above.](PolicyWonk.LoadResource.html#module-specifying-loaders)
  """

  def init( opts ) when is_list(opts), do: do_init(opts[:resource_module], opts[:resources], opts[:async])

  defp do_init( nil, _, _ ), do: raise Error, message: "#{IO.ANSI.red}Must supply a valid :resource_module#{IO.ANSI.default_color()}"
  defp do_init( _, [], _ ), do: raise Error, message: "#{IO.ANSI.red}Must supply at least one resource to load#{IO.ANSI.default_color()}"

  defp do_init( resource_module, resources, async ) when is_atom(resource_module) and is_list(resources) do
    %{
      resource_module: resource_module,
      resources: resources,
      async: async
    }
  end

  defp do_init( policy_module, policy, async ) do
    do_init( policy_module, [policy], async )
  end

  #----------------------------------------------------------------------------
  @doc """
  Call is used by the plug stack. 
  """
  def call(conn, %{resource_module: resource_module, resources: resources, async: async}) do
    PolicyWonk.Loader.load(conn, resource_module, resources, async)
  end

end
