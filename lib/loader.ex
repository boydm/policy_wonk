defmodule PolicyWonk.Loader do
  
  @callback load_resource(Plug.Conn.t, atom, Map.t) :: {:ok, any} | {:error, any}
  @callback load_error(Plug.Conn.t, any) :: Plug.Conn.t

end