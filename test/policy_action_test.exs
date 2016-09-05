defmodule PolicyWonk.PolicyActionTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.PolicyAction
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
    assert PolicyAction.init() == %{handler: nil}
  end

  #----------------------------------------------------------------------------
  test "init accepts a handler override" do
    assert PolicyAction.init(ModA) == %{handler: ModA}
  end

  #----------------------------------------------------------------------------
  test "init handles [] as nil" do
    assert PolicyAction.init([]) == %{handler: nil}
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
    PolicyAction.call(conn, %{handler: nil})
  end

  #----------------------------------------------------------------------------
  test "calls into override handler first", %{conn: conn} do
    conn = Map.put( conn,
      :private,
      %{phoenix_controller: ModController, phoenix_action: :index}
    )
    PolicyAction.call(conn, %{handler: ModA})
  end

  #----------------------------------------------------------------------------
  test "call raises if there is no phoenix_action", %{conn: conn} do
    assert_raise PolicyWonk.PolicyAction, fn ->
      PolicyAction.call(conn, %{handler: nil})
    end
  end

  #----------------------------------------------------------------------------
  test "call raises if policy not found", %{conn: conn} do
    conn = Map.put( conn,
      :private,
      %{phoenix_controller: ModController, phoenix_action: :missing}
    )
    assert_raise PolicyWonk.Policy, fn ->
      PolicyAction.call(conn, %{handler: nil})
    end
  end


end