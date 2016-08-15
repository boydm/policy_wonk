defmodule PolicyWonk do
  
  # define a policy error here - not found or something like that
  defmodule PolicyError do
    defexception [message: "#{IO.ANSI.red}Unable to execute a policy\n"]
  end

  #===========================================================================
  defmacro __using__(_opts) do
    quote do
      @policy_wonk_policies Application.get_env(:policy_wonk, PolicyWonk)[:policy_modules]

      #------------------------------------------------------------------------
      def authorized?(conn, action_or_name) do
        handlers = [ __MODULE__ ]
          |> PolicyWonk.Utils.append_truthy( @policy_wonk_policies )
          |> PolicyWonk.Utils.append_truthy( conn.private[:phoenix_router] )
  #      IO.puts "~~~~~~~~~~~~> #{inspect(handlers)}"
        case PolicyWonk.Utils.call_policy(handlers, conn, action_or_name) do
          :ok ->        true
          true ->       true
          false ->      false
          {:ok, _} ->   true
          {:err, _} ->  false
          _         ->  false
        end
      end
      
    end # quote
  end # defmacro

end