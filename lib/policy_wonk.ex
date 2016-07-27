defmodule PolicyWonk do

  #===========================================================================
  defmacro __using__(_opts) do
    quote do
      
      #------------------------------------------------------------------------
      def is_authorized?(conn, action_or_name) do
        case policy(conn, action_or_name) do
          {:ok, _}            -> true
          _                   -> false
        end
      end
      
    end # quote
  end # defmacro

end