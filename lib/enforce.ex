defmodule PolicyWonk.Enforce do
  @moduledoc """

  This turns your policy module into a plug that can be used in a router.

  ## Usage

  The only time you should directly use the `PolicyWonk.Enforce` module is to call
  `use PolicyWonk.Enforce` when defining your policy module.


  Example policy module:

        defmodule MyAppWeb.Policies do
          use PolicyWonk.Policy         # set up support for policies
          use PolicyWonk.Enforce        # turn this module into an enforcement plug

          def policy( assigns, :current_user ) do
            case assigns[:current_user] do
              %MyApp.Account.User{} ->
                :ok
              _ ->
                {:error, :current_user}
            end
          end

          def policy_error(conn, :current_user) do
            MyAppWeb.ErrorHandlers.unauthenticated(conn, "Must be logged in")
          end
        end


  To enforce your policies as a plug, you can just use the new module you created.

  Enforce policies in a router:

        pipeline :browser_session do
          plug MyAppWeb.Policies,  :current_user
          plug MyAppWeb.Policies,  [:policy_a, :policy_b]
        end
  """

  # ===========================================================================
  defmacro __using__(use_opts) do
    quote do
      @doc false
      def init(policies_or_opts) do
        case Keyword.keyword?(policies_or_opts) do
          true ->
            policies_or_opts
            |> Keyword.put_new(:policy_module, unquote(use_opts[:policy_module]) || __MODULE__)
            |> PolicyWonk.Enforce.init()

          false ->
            PolicyWonk.Enforce.init(policy_module: __MODULE__, policies: policies_or_opts)
        end
      end

      @doc false
      def call(conn, opts), do: PolicyWonk.Enforce.call(conn, opts)
    end

    # quote
  end

  # defmacro

  # ===========================================================================
  # define a policy enforcement error here
  defmodule Error do
    @moduledoc false
    defexception message: "#{IO.ANSI.red()}Policy endforcement failed#{IO.ANSI.default_color()}\n"
  end

  # ===========================================================================

  @doc false
  def init(opts) when is_list(opts), do: do_init(opts[:policy_module], opts[:policies])

  defp do_init(nil, _),
    do:
      raise(
        Error,
        message: "#{IO.ANSI.red()}Must supply a valid :policy_module#{IO.ANSI.default_color()}"
      )

  defp do_init(_, []),
    do:
      raise(
        Error,
        message:
          "#{IO.ANSI.red()}Must supply at least one policy to enforce#{IO.ANSI.default_color()}"
      )

  defp do_init(policy_module, policies) when is_atom(policy_module) and is_list(policies) do
    %{
      policy_module: policy_module,
      policies: policies
    }
  end

  defp do_init(policy_module, policy) do
    do_init(policy_module, [policy])
  end

  # ----------------------------------------------------------------------------
  # ------------------------------------------------------------------------
  @doc false
  def call(conn, %{policy_module: policy_module, policies: policies}) do
    PolicyWonk.Policy.enforce(conn, policy_module, policies)
  end
end
