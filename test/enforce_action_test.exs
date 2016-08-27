defmodule PolicyWonk.EnforceActionTest do
  use ExUnit.Case, async: false
  alias PolicyWonk.EnforceAction
  doctest PolicyWonk

  defmodule ModA do
    def policy( conn, :index ) do
      {:ok, Plug.Conn.assign(conn, :found, "mod_a_index")}
    end
  end

  defmodule ModController do
    def policy( conn, :index ) do
      {:ok, Plug.Conn.assign(conn, :found, "controller_index")}
    end
  end

  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end


  #============================================================================
  # init
  #----------------------------------------------------------------------------
  test "init filters options - including policies" do
    assert EnforceAction.init(%{
      policies: [:a,:b],
      handler: ModA,
      invalid: "invalid"
    }) == %{handler: ModA, policies: nil}
  end

  #----------------------------------------------------------------------------
  test "init defaults to nil handler" do
    assert EnforceAction.init(%{
    }) == %{handler: nil, policies: nil}
  end

  #============================================================================
  # call
  #----------------------------------------------------------------------------
  test "call tests current action as a policy", %{conn: conn} do
    conn = Map.put( conn,
      :private,
      %{phoenix_controller: ModController, phoenix_action: :index}
    )
    conn = EnforceAction.call(conn, %{handler: nil})
    assert conn.assigns.found == "controller_index"
  end

  #----------------------------------------------------------------------------
  test "calls into set handler first", %{conn: conn} do
    conn = Map.put( conn,
      :private,
      %{phoenix_controller: ModController, phoenix_action: :index}
    )
    conn = EnforceAction.call(conn, %{handler: ModA})
    assert conn.assigns.found == "mod_a_index"
  end

  test "call raises if there is no phoenix_action", %{conn: conn} do
    assert_raise PolicyWonk.EnforceAction.Error, fn ->
      EnforceAction.call(conn, %{handler: nil})
    end
  end
end