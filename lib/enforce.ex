defmodule PolicyWonk.Enforce do
  alias PolicyWonk.Utils

  @config_policies Application.get_env(:policy_wonk, PolicyWonk)[:policies]


  #===========================================================================
  defmacro __using__(_opts) do
    quote do
      #------------------------------------------------------------------------
      def authorized?(conn, policies) do
        PolicyWonk.Enforce.authorized?(__MODULE__, conn, policies)
      end
    end # quote
  end # defmacro



  #===========================================================================
  # define a policy error here - not found or something like that
  defexception [message: "#{IO.ANSI.red}Unable to execute a policy\n"]


  #===========================================================================
  #------------------------------------------------------------------------
  def authorized?(handler, conn = %Plug.Conn{}, policies), do:
    authorized?(handler, conn.assigns, policies)
  def authorized?(handler, data, policies) when is_list(policies) do
    handlers = []
      |> Utils.append_truthy( handler )
      |> Utils.append_truthy( @config_policies )

    case evaluate_policies(handlers, data, policies) do
      :ok -> true
      _   -> false
    end
  end
  def authorized?(handler, data, policy), do:
    authorized?(handler, data, [policy])


  #===========================================================================
  def init(%{policies: []}),                  do: init_empty_policies_error()
  def init(%{policies: policies, handler: handler})
                            when is_list(policies) and is_atom(handler), do:
    %{policies: policies, handler: handler}
  def init(%{policies: policies, handler: handler}) when is_atom(handler), do:
    init( %{policies: [policies], handler: handler} )
  def init(%{policies: policies}),            do: init( policies )
  def init(policies) when is_list(policies),  do: init( %{policies: policies, handler: nil} )
  def init(policy),                           do: init( %{policies: [policy], handler: nil} )
  #--------------------------------------------------------
  defp init_empty_policies_error() do
    msg = "PolicyWonk.Enforce requires at least one policy reference"
    raise %PolicyWonk.Enforce{ message: msg }
  end


  #----------------------------------------------------------------------------
  def call(conn, opts) do
    # figure out what handler to use
    handler = opts.handler ||
      Utils.controller_module(conn) ||
      Utils.router_module(conn)

    handlers = []
      |> Utils.append_truthy( handler )
      |> Utils.append_truthy( @config_policies )

    # evaluate the policies. Cal error func if any fail
    case evaluate_policies( handlers, conn.assigns, opts.policies ) do
      :ok ->
        # continue without transforming the conn
        conn
      err_data ->
        # halt the plug chain
        call_policy_error( handlers, conn, err_data )
        |> Plug.Conn.halt
    end
  end # def call


  #----------------------------------------------------------------------------
  def evaluate_policies(handlers, assigns, policies ) do
    handlers = Enum.uniq(handlers)
    policies = Enum.uniq(policies)
    # Enumerate through all the policies. Fail if any fail
    Enum.reduce_while( policies, :ok, fn(policy, _acc) ->
      #case handler.Enforce( conn, policy ) do
      case call_policy( handlers, assigns, policy ) do
        :ok ->      {:cont, :ok}
        err_data -> {:halt, err_data }
      end
    end)
  end


  #----------------------------------------------------------------------------
  defp call_policy( handlers, assigns, policy ) do
    try do
      Utils.call_down_list(handlers, fn(handler) ->
        handler.policy(assigns, policy)
      end)
    catch
      # if a match wasn't found on the module, try the next in the list
      :not_found ->
        # policy wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}policy#{IO.ANSI.red} definition for:\n" <>
          "#{IO.ANSI.green}Policy: #{IO.ANSI.yellow}#{inspect(policy)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.Enforce{ message: msg }
    end
  end

  #----------------------------------------------------------------------------
  defp call_policy_error(handlers, conn, err_data ) do
    try do
      Utils.call_down_list(handlers, fn(handler) ->
        handler.policy_error(conn, err_data)
      end)
    catch
      # if a match wasn't found on the module, try the next in the list
      :not_found ->
        # policy wasn't found on any handler. raise an error
        msg = "#{IO.ANSI.red}Unable find to a #{IO.ANSI.yellow}policy_error#{IO.ANSI.red} definition for...\n" <>
          "#{IO.ANSI.green}err_data: #{IO.ANSI.red}#{inspect(err_data)}\n" <>
          "#{IO.ANSI.green}In any of the following modules...#{IO.ANSI.yellow}\n" <>
          Utils.build_handlers_msg( handlers ) <>
          IO.ANSI.red
        raise %PolicyWonk.Enforce{ message: msg }
    end
  end

end