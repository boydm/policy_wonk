defmodule PolicyWonk do

  #===========================================================================
  defmacro __using__(_opts) do
    quote do
      
      #------------------------------------------------------------------------
      def authorized?(conn, action_or_name) do
        case policy(conn, action_or_name) do
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