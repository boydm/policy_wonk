defmodule PolicyWonk.EnforceTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Enforce
  doctest PolicyWonk

#  import IEx

  defmodule ModA do
    def policy( conn, :generic ) do
      {:ok, Plug.Conn.assign(conn, :found, "mod_a_generic")}
    end
    def policy( _conn, :ok_ok ),      do: :ok
    def policy( _conn, :ok_true ),    do: true
    def policy( _conn, :fail_data ),  do: {:err, "err_data"}
    def policy( _conn, :fail_err ),   do: :err
    def policy( _conn, :fail_error ), do: :error
    def policy( _conn, :fail_false ), do: false
    def policy( _conn, :fail_other ), do: "fail_other"

    def policy_error(conn, "err_generic"),  do: Plug.Conn.assign(conn, :errd, "err_generic")
    def policy_error(_conn, "invalid"),     do: "invalid"
  end


  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #============================================================================
  # call_policy
  #----------------------------------------------------------------------------
  test "call_policy calls policy handlers", %{conn: conn} do
    {:ok, conn} = Enforce.call_policy([ModA], conn, :generic)
    assert conn.assigns.found == "mod_a_generic"
  end

  #----------------------------------------------------------------------------
  test "call_policy returns conn if :ok", %{conn: conn} do
    assert Enforce.call_policy([ModA], conn, :ok_ok) == {:ok, conn}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns conn if true", %{conn: conn} do
    assert Enforce.call_policy([ModA], conn, :ok_true) == {:ok, conn}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns error data", %{conn: conn} do
    assert Enforce.call_policy([ModA], conn, :fail_data) == {:err, conn, "err_data"}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns nil error data on false, :err, or :error", %{conn: conn} do
    assert Enforce.call_policy([ModA], conn, :fail_false) == {:err, conn, nil}
    assert Enforce.call_policy([ModA], conn, :fail_err) ==   {:err, conn, nil}
    assert Enforce.call_policy([ModA], conn, :fail_error) == {:err, conn, nil}
  end

  #----------------------------------------------------------------------------
  test "call_policy raises on unknown responses", %{conn: conn} do
    assert_raise RuntimeError, fn ->
      Enforce.call_policy([ModA], conn, :fail_other)
    end
  end

  #============================================================================
  # call_policy_error
  #----------------------------------------------------------------------------
  test "call_policy_error calls policy handlers", %{conn: conn} do
    conn = Enforce.call_policy_error([ModA], conn, "err_generic")
    assert conn.assigns.errd == "err_generic"
  end

  #----------------------------------------------------------------------------
  test "call_policy_error raises on missing handler", %{conn: conn} do
    assert_raise PolicyWonk.Enforce.Error, fn ->
      Enforce.call_policy_error([ModA], conn, "missing")
    end
  end

  #----------------------------------------------------------------------------
  test "call_policy_error raises on unknown responses", %{conn: conn} do
    assert_raise RuntimeError, fn ->
      Enforce.call_policy_error([ModA], conn, "invalid")
    end
  end


end