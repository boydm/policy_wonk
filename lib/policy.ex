defmodule PolicyWonk.Policy do

  @callback policy(Plug.Conn.t, any) :: :ok | any
  @callback policy_error(Plug.Conn.t, any) :: Plug.Conn.t

end