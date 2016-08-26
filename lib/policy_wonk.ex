defmodule PolicyWonk do
  alias PolicyWonk.Utils

  # define a policy error here - not found or something like that
  #===========================================================================
  defmacro __using__(_opts) do
    quote do
      @policy_wonk_policies Application.get_env(:policy_wonk, PolicyWonk)[:policy_modules]

      #------------------------------------------------------------------------
      def authorized?(conn, action_or_name) do
        handlers = [ __MODULE__ ]
          |> Utils.append_truthy( @policy_wonk_policies )
          |> Utils.append_truthy( Utils.map_exists(conn, [:private, :phoenix_router]) )
        case Utils.call_policy(handlers, conn, action_or_name) do
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