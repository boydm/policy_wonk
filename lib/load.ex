defmodule PolicyWonk.Load do
  @moduledoc """

  This turns your resource module into a plug that can be used in a router.

  ## Usage

  The only time you should directly use the `PolicyWonk.Load` module is to call
  `use PolicyWonk.Load` when defining your resource module.


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


  To use your resources as a plug, you can just use the new module you created.

  Load resoruces in a router:

        pipeline :browser_session do
          plug MyAppWeb.Resources,  :user
          plug MyAppWeb.Resources,  [:thing_a, :thing_b]
        end

  You can also pass in a Keyword list with additional options

        plug MyAppWeb.Resources,  resources: [:user, :thing_a], async: true

  If you use the keyword list of options, then the available options are
    * resources: a list of resources to load
    * async: a true/false flag indicating if the resources should be loaded asynchronously

  ## async load default

  When you add `use PolicyWonk.Load` to your resource module, the default is to set async
  loading to false. If you would like to set it as true, you can set as a use option.

        defmodule MyAppWeb.Resources do
          use PolicyWonk.Resource               # set up support for resources
          use PolicyWonk.Load, async: true      # turn this module into an resource loading into a plug
  """

  # ===========================================================================
  # the using macro for loaders adopting this behavioiur
  defmacro __using__(use_opts) do
    quote do
      @doc false
      def init(resources_or_opts) do
        PolicyWonk.Load.plug_init(
          resources_or_opts,
          unquote(use_opts[:resource_module]) || __MODULE__,
          unquote(use_opts[:async])
        )
      end

      @doc false
      def call(conn, opts), do: PolicyWonk.Load.call(conn, opts)
    end

    # quote
  end

  # defmacro

  # ===========================================================================
  # define a policy error here - not found or something like that
  defmodule Error do
    @moduledoc false
    defexception message: "#{IO.ANSI.red()}Load resource failed#{IO.ANSI.default_color()}\n"
  end

  # ===========================================================================
  # --------------------------------------------------------
  @doc false
  def init(opts) when is_list(opts) do
    async =
      case opts[:async] do
        true -> true
        _ -> false
      end

    do_init(opts[:resource_module], opts[:resources], async)
  end

  # --------------------------------------------------------
  @doc false
  def plug_init(resources_or_opts, module, async) do
    case Keyword.keyword?(resources_or_opts) do
      true ->
        resources_or_opts
        |> Keyword.put_new(:resource_module, module)
        |> Keyword.put_new(:async, async)
        |> init()

      false ->
        do_init( module, resources_or_opts, false)
    end
  end

  # --------------------------------------------------------
  defp do_init(nil, _, _),
    do:
      raise(
        Error,
        message: "#{IO.ANSI.red()}Must supply a valid :resource_module#{IO.ANSI.default_color()}"
      )

  defp do_init(_, [], _),
    do:
      raise(
        Error,
        message:
          "#{IO.ANSI.red()}Must supply at least one resource to load#{IO.ANSI.default_color()}"
      )

  defp do_init(resource_module, resources, async)
       when is_atom(resource_module) and is_list(resources) do
    %{
      resource_module: resource_module,
      resources: resources,
      async: async
    }
  end

  defp do_init(policy_module, policy, async) do
    do_init(policy_module, [policy], async)
  end

  # --------------------------------------------------------
  @doc false
  def call(conn, %{resource_module: resource_module, resources: resources, async: async}) do
    PolicyWonk.Resource.load(conn, resource_module, resources, async)
  end
end
