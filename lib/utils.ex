defmodule PolicyWonk.Utils do
  @moduledoc false
  
  #----------------------------------------------------------------------------
  def call_into_list( handlers, callback ) when is_list(handlers) and is_function(callback) do
    {:ok, answer} = Enum.find_value(handlers, {:ok, :not_found}, fn(handler) ->
      case handler do
        nil -> false  # empty spot in the handler list
        h ->
          try do
            {:ok, callback.( h )}
          rescue
            # if a match wasn't found on the module, try the next in the list
            _e in UndefinedFunctionError -> false
            _e in FunctionClauseError ->    false
            # some other error. let it raise
            e -> raise e
          end
      end
    end)
    answer
  end

  #----------------------------------------------------------------------------
  def build_handlers_msg( handlers ) do
    Enum.reduce(handlers, "", fn(h, acc) ->
      case h do
        nil -> acc
        mod -> acc <> inspect(mod) <> "\n"
      end
    end)
  end

  #----------------------------------------------------------------------------
  # append element to list, but only if the element is truthy
  def append_truthy(list, element) when is_list(list) do
    cond do
      is_list(element) -> list ++ element
      element ->          list ++ [element]
      true ->             list
    end
  end

  #----------------------------------------------------------------------------
  # get a nested value from a map. Returns nil if either the value or the map it is
  # nested in doesn't exist
  def get_exists(map, atribute) when is_atom(atribute), do: get_exists(map, [atribute]) 
  def get_exists(map, [head | []]) do
    Map.get(map, head, nil)
  end
  def get_exists(map, [head | tail]) do
    value = Map.get(map, head, nil)
    cond do
      is_map(value) -> get_exists(value, tail)
      true -> nil
    end
  end

end

