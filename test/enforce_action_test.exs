defmodule PolicyWonk.EnforceActionTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.EnforceAction
  doctest PolicyWonk

  defmodule ModA do
    def policy( _assigns, :index ) do
      :ok
    end
  end

  defmodule ModController do
    def policy( _assigns, :index ) do
      :ok
    end
  end


  #============================================================================
  # init
  #----------------------------------------------------------------------------
  test "init setup up correctly with no parameters" do
    assert EnforceAction.init() == %{handler: nil}
  end

  #----------------------------------------------------------------------------
  test "init accepts a handler override" do
    assert EnforceAction.init(ModA) == %{handler: ModA}
  end

  #----------------------------------------------------------------------------
  test "init handles [] as nil" do
    assert EnforceAction.init([]) == %{handler: nil}
  end



  #============================================================================
  # call
  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #----------------------------------------------------------------------------
  test "call tests current action as a policy", %{conn: conn} do
    conn = Map.put( conn,
      :private,
      %{phoenix_controller: ModController, phoenix_action: :index}
    )
    EnforceAction.call(conn, %{handler: nil})
  end

  #----------------------------------------------------------------------------
  test "calls into override handler first", %{conn: conn} do
    conn = Map.put( conn,
      :private,
      %{phoenix_controller: ModController, phoenix_action: :index}
    )
    EnforceAction.call(conn, %{handler: ModA})
  end

  #----------------------------------------------------------------------------
  test "call raises if there is no phoenix_action", %{conn: conn} do
    assert_raise PolicyWonk.EnforceAction, fn ->
      EnforceAction.call(conn, %{handler: nil})
    end
  end

  #----------------------------------------------------------------------------
  test "call raises if policy not found", %{conn: conn} do
    conn = Map.put( conn,
      :private,
      %{phoenix_controller: ModController, phoenix_action: :missing}
    )
    assert_raise PolicyWonk.Enforce, fn ->
      EnforceAction.call(conn, %{handler: nil})
    end
  end


end