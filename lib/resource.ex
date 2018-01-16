defmodule PolicyWonk.Resource do
  @moduledoc """

  # Overview
  
  A resource loader is a function that loads (or prepares) a single resource. The result is put
  into the conn's assigns field.

    A simple resource loader:

      def resource( _conn, :user, %{"id" => user_id} ) do
        case MyAppWeb.Account.get_user(user_id) do
          nil ->  {:error, :not_found}
          user -> {:ok, :user, user}
        end
      end

  The above loader takes the `user_id` (which is from the params of the current request) and
  attemps to load a user model from the database. The result is put into the conn's assigns field
  under the `:user` key.

  Your loaders don't need to hit a database. You could generate data or otherwise prepare something
  else. The point is that the result gets put into the conn's assigns map.

  ## Usage

  The only time you should directly use the `PolicyWonk.Resource` module is to call
  `use PolicyWonk.Resource` when defining your resource loader module.

  `use PolicyWonk.Resource` injects the `load/3`, `load!/3`, functions into your loader modules.
  These run and evaluate your resource functions and act accordingly on the results.

  Loading resources during the plug chain has several important benefits:

  * When a resource can't be loaded, you can halt the plug chain and handle the error before your
  actions get called. This lets you code your actions for the happy path.
  * Reuse and consistency improves in how resources are loaded. You can write one loader that
  is accessed by many controllers or router pipelines.
  * It lets you enforce policies on the resources before your actions are called. The best way to
  avoid security mistakes is to never run that code in the first place.
   
  The *only* way to indicate success from a `resource` function is to return a tuple such as
  `{:ok, key, resource}`. The first field in the tuple must be `:ok` to indicate success. The middle
  field is the name of the resource as you want it assigned into `conn.assigns`. The last field
  is the resource itself.

  The idea is that you define multiple `resource` functions and use Elixir’s pattern matching to
  find the right one. Like policies, this loader name could be an atom, tuple, map or really
  anything Elixir/Erlang can match against.

  If the resource fails to load, return {:error, message}, which will in turn pass the message term
  to your loader_error callback.

  In general, if a requested resource fails to load, it halts the plug and handles the error before
  the request controller action is ever run. This front-loads the resource loading checks before
  the controller/actions using router pipelines as a choke point.


  Example resource loader module:

        defmodule MyAppWeb.Resources do
          use PolicyWonk.Resource       # set up support for resources
          use PolicyWonk.Load           # turn this module into an resource loading into a plug

          def resource( _conn, :user, %{"id" => user_id} ) do
            case MyAppWeb.Account.get_user(user_id) do
              nil ->  {:error, :not_found}
              user -> {:ok, :user, user}
            end
          end

          def policy_error(conn, :not_found) do
            MyAppWeb.ErrorHandlers.resource_not_found(conn, "Resource Not Found")
          end
        end


  ## Injected functions

  When you call `use PolicyWonk.Resource`, the following functions are injected into your module.

  ### load/3

  `load(conn, resource, async \\ false)`

  Callable as a local plug. Load accepts the current conn and a resource indicator.
  It then calls the resource function, evaluates the response and either
  puts the result into conn.assigns or transforms the conn with a failure.

  You will normally only use this function if you want to enforce a policy that is
  written into a controller. Then the plug call will look like this:

        plug :load, :some_resource


  If you want to enforce a policy from your router, please read the `PolicyWonk.Load`
  documentation.

  parameters:

  * `conn` The current conn in the plug chain
  * `resource` The resource or resources you want to load. This can be either a single
  term representing one resource, or a list of resource terms.
  * 'async' a true/false flag indicating if the resources passed in a list should be
  loaded asynchronously or not.


  ### load!/3

  `load!(conn, resource, async \\ false)`

  Loads a resource and returns it. Raises when the `resource` function returns `{:error, message}`.
  This is a handy way to use your `resource` functions from within an action in a controller.

  If multiple resources are requested the loaded resources are returned in a list of tuples
  indicating which resources are which.


        load!(conn, [:user, :thing])
        # returns something like...
        [{:user, user}, {:thing, thing}]

  parameters:

  * `conn` The current conn in the plug chain
  * `resource` The resource or resources you want to load. This can be either a single
  term representing one resource, or a list of resource terms.
  * 'async' a true/false flag indicating if the resources passed in a list should be
  loaded asynchronously or not.

  ## Loader Failures

  To gracefully handle a load error, return a `{:error, message}` tuple.

  `PolicyWonk.Load` will then cease attempting to load other resources and call your
  `resource_error(conn, message)` function. The `message` parameter is what you returned from your
  `resource` function.

      def resource_error(conn, message) do
        conn
        |> put_status(404)
        |> put_view(MyApp.ErrorView)
        |> render("404.html")
        |> halt()
      end

  The `resource_error` function works just like a regular plug function. It takes a `conn`, and
  whatever was returned from the loader. You can manipulate the `conn` however you want to
  respond to that error. Then return the `conn`.

  Unlike handling a policy error, `halt(conn)` is not called for you. If you want the
  resource load failure to halt the plug chain, make sure to call `halt(conn)` in your
  `resource_error` function.

  Sometimes you want the plug chain to continue with a nil resource...

  ## Use outside the plug chain

  Resources are usually loaded through a plug, but can also be used inside of other code, such
  as an action. If you are just reading from a db, then you should probably call your model context
  functions instead. But if it does something more complicated to prepare a resource, then this
  can be pretty handy.

  In an action in a controller:

        def settings(conn, params) do
          ...
          # raise an error if the resource fails to load.
          resource = MyAppWeb.Resources.load!(conn, :some_resource)
          ...
        end


  ## Loader Locations

  You can build as many Loader modules as you want in multiple umbrella applications. Simply
  call `use PolicyWonk.Resource` to add the support functions to your module. Call `use PolicyWonk.Load`
  to make your module a plug that can be called in the router.

  """

  @doc """
  Load a resource.

  ## parameters
  * `conn`, the current conn in the plug chain. For informational purposes.
  * `resource`, The resource term you requested with invoking the plug
  * `params`, the `params` field from the current `conn`. Passed in as a convenience. Useful for
  parsing and matching against.

  ## Return values

  Must return either {:ok, key, resource} or {:error, message}. If it is an error, the message term will be pass on
  you your resource_error callback unchanged.

  Example:
        def resource( _conn, :user, %{"id" => user_id} ) do
          case Repo.get(Account.User, user_id) do
            nil ->  {:error, "User not found"}
            user -> {:ok, :user, user}
          end
        end
  """
  @callback resource(conn :: Plug.Conn.t(), resource :: any, params :: Map.t()) :: {:ok, atom, any} | {:error, any}

  @doc """
  Handle a resource load error. Only called during the plug chain.

  Must return a conn, which you are free to transform.

  ## parameters
  * `conn`, the current conn in the plug chain. Transform this to handle the error.
  * `message`, the `message` returned from your `resource` function.

  Example:
        def resource_error(conn, message) do
          conn
          |> put_status(404)
          |> put_view(MyApp.ErrorView)
          |> render("404.html")
          |> halt()
        end
    
  Unlike policies, if you want to halt the plug chain on a resource load error, you
  must call halt() yourself during the `resource_error` function.
  """
  @callback resource_error(conn :: Plug.Conn.t(), message :: any) :: Plug.Conn.t()

  @format_error "Loaders must return either {:ok, key, resource} or an {:error, message}"

  # ===========================================================================
  # define a policy error here - not found or something like that
  defmodule Error do
    @moduledoc false
    defexception message: "#{IO.ANSI.red()}Load Resource Failure\n", module: nil, resource: nil
  end

  # ===========================================================================
  defmacro __using__(_use_opts) do
    quote do
      @behaviour PolicyWonk.Resource

      # ----------------------------------------------------
      @doc """
      Callable as a local plug. Loads one or more resources.

      You will normally only use this function if you want to enforce a policy that is
      written into a controller. Then the plug call will look like this:

            plug :load, :some_resource


      If you want to load a resource from your router, please read the `PolicyWonk.Load`
      documentation.

      ## Parameters
      * `conn` The current conn in the plug chain
      * `resource` The resource or resources you want to load. This can be either a single
      term representing one resource, or a list of resource terms.
      * `async` flag indicating if a list of resources should be loaded asynchronously.
      """
      def load(conn, resources, async \\ false) do
        PolicyWonk.Resource.load(conn, __MODULE__, resources, async)
      end

      # ----------------------------------------------------
      @doc """
      Evaluates one or more resource loaders and returns the results. 

      In an action in a controller:

            def settings(conn, params) do
              ...
              # raise an error if the resource fails to load.
              resource = MyAppWeb.Resources.load!(conn, :some_resource)
              ...
            end

      If multiple resources are requested, they will be returned in a list of tuples.

            MyAppWeb.Resources.load!(conn, [:thing_a, :thing_b])
            # would return something like
            [{:thing_a, thing_a}, {:thing_b, thing_b}]

      ## Parameters
      * `conn` The current conn in the plug chain
      * `resource` The resource or resources you want to load. This can be either a single
      term representing one resource, or a list of resource terms.
      * `async` flag indicating if a list of resources should be loaded asynchronously.
      """

      def load!(conn, resources, async \\ false),
        do: PolicyWonk.Resource.load!(conn, __MODULE__, resources, async)
    end
  end

  # ----------------------------------------------------
  # Enforce called as a (internal) plug
  @doc false
  def load(conn, module, resources, async \\ false)

  # don't do anything if the conn is already halted
  def load(%Plug.Conn{halted: true} = conn, _, _, _), do: conn

  # load a list of resources, synchronously
  def load(%Plug.Conn{} = conn, module, resources, false) when is_list(resources) do
    Enum.reduce(resources, conn, &load(&2, module, &1, false))
  end

  # load a list of resources, asynchronously
  def load(%Plug.Conn{} = conn, module, resources, true) when is_list(resources) do
    # spin up tasks for all the loads
    # wait for the async tasks to complete - assigning each into the conn
    resources
    |> Enum.map(fn resource ->
      Task.async(fn -> do_load_resource(conn, module, resource) end)
    end)
    |> Enum.reduce_while(conn, fn task, acc_conn ->
      case Task.await(task) do
        {:ok, key, resource} ->
          {:cont, Plug.Conn.assign(acc_conn, key, resource)}

        {:error, message} ->
          # handle the error
          acc_conn = module.resource_error(acc_conn, message)
          {:cont, acc_conn}
      end
    end)
  end

  # load a single resource
  def load(%Plug.Conn{} = conn, module, resource, _) do
    case module.resource(conn, resource, conn.params) do
      {:ok, key, resource} ->
        Plug.Conn.assign(conn, key, resource)

      {:error, message} ->
        # handle the error
        module.resource_error(conn, message)
    end
  end

  # ----------------------------------------------------
  # load that returns the resource or raises an error
  @doc false
  def load!(conn, module, resources, async \\ false)

  # load! a list of resources, synchronously
  def load!(%Plug.Conn{} = conn, module, resources, false) when is_list(resources) do
    resources
    |> Enum.reduce([], fn resource, acc ->
      [{resource, load!(conn, module, resource)} | acc]
    end)
    |> Enum.reverse()
  end

  # load! a list of resources, asynchronously
  def load!(%Plug.Conn{} = conn, module, resources, true) when is_list(resources) do
    # spin up tasks for all the resources
    # wait for the async tasks to complete - assigning each into the conn
    resources
    |> Enum.map(fn resource ->
      Task.async(fn -> do_load_resource(conn, module, resource) end)
    end)
    |> Enum.reduce_while([], fn task, acc ->
      case Task.await(task) do
        {:ok, key, resource} ->
          {:cont, [{key, resource} | acc]}

        {:error, resource, message} ->
          raise_error(message, module, resource)
      end
    end)
  end

  # load! a single resource
  def load!(%Plug.Conn{} = conn, module, resource, _) do
    case module.resource(conn, resource, conn.params) do
      {:ok, _, resource} ->
        resource

      {:error, message} ->
        raise_error(message, module, resource)

      _ ->
        raise_error(@format_error, module, resource)
    end
  end

  # ============================================================================

  # --------------------------------------------------------
  defp do_load_resource(conn, module, resource) do
    case module.resource(conn, resource, conn.params) do
      {:ok, key, resource} ->
        {:ok, key, resource}

      {:error, message} ->
        {:error, message}

      _ ->
        raise_error(@format_error, module, resource)
    end
  end

  # --------------------------------------------------------
  defp raise_error(message, module, resource) do
    message =
      message <>
        "\n" <>
        "#{IO.ANSI.green()}module: #{IO.ANSI.yellow()}#{inspect(module)}\n" <>
        "#{IO.ANSI.green()}resource: #{IO.ANSI.yellow()}#{inspect(resource)}\n" <>
        IO.ANSI.default_color()

    raise Error, message: message, module: module, resource: resource
  end
end
