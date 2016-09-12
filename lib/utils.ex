defmodule PolicyWonk.Utils do
  @moduledoc false


  #----------------------------------------------------------------------------
  @spec call_down_list(List.t, function) :: any
  def call_down_list( [], _callback ), do: throw :not_found
  def call_down_list( [nil | tail], callback ), do: call_down_list(tail, callback)
  def call_down_list( [module | tail], callback ) when is_function(callback) do
    try do
      callback.( module )
    rescue
      # if a match wasn't found on the module, try the next in the list
      _e in [UndefinedFunctionError, FunctionClauseError] ->
        call_down_list(tail, callback)
      # some other error. let it raise
      e -> raise e
    end
  end

  #----------------------------------------------------------------------------
  @spec build_modules_msg(List.t) :: String.t
  def build_modules_msg( modules ) do
    Enum.reduce(modules, "", fn(h, acc) ->
      case h do
        nil -> acc
        mod -> acc <> inspect(mod) <> "\n"
      end
    end)
  end

  #----------------------------------------------------------------------------
  # append element to list, but only if the element is truthy
  @spec append_truthy(List.t, any) :: List.t
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
  @spec get_exists(Map.t, atom) :: any
  @spec get_exists(Map.t, [atom]) :: any
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

  #----------------------------------------------------------------------------
  @spec controller_module(Plug.Conn.t) :: atom
  def controller_module(conn) do
    get_exists(conn, [:private, :phoenix_controller])
  end

  #----------------------------------------------------------------------------
  @spec action_name(Plug.Conn.t) :: atom
  def action_name(conn) do
    get_exists(conn, [:private, :phoenix_action])
  end

  #----------------------------------------------------------------------------
  @spec router_module(Plug.Conn.t) :: atom
  def router_module(conn) do
    get_exists(conn, [:private, :phoenix_router])
  end

end

