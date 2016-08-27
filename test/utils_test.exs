defmodule PolicyWonk.UtilsTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Utils
  doctest PolicyWonk

  import IEx

  defmodule ModA do
    def policy( conn, :generic ) do
      {:ok, Plug.Conn.assign(conn, :found, "mod_a_generic")}
    end
    def policy( conn, :mod_a_policy ) do
      {:ok, Plug.Conn.assign(conn, :found, "mod_a_policy")}
    end
    def policy_error(conn, "err_generic"),  do: Plug.Conn.assign(conn, :errd, "err_generic_a")
    def policy_error(conn, "err_data_a"),   do: Plug.Conn.assign(conn, :errd, "err_data_a")
  end

  defmodule ModB do
    def policy( conn, :generic ) do
      {:ok, Plug.Conn.assign(conn, :found, "mod_b_generic")}
    end
    def policy( conn, :mod_b_policy ) do
      {:ok, Plug.Conn.assign(conn, :found, "mod_b_policy")}
    end
    def policy( _conn, :ok_ok ),      do: :ok
    def policy( _conn, :ok_true ),    do: true
    def policy( _conn, :fail_data ),  do: {:err, "err_data"}
    def policy( _conn, :fail_err ),   do: :err
    def policy( _conn, :fail_error ), do: :error
    def policy( _conn, :fail_false ), do: false
    def policy( _conn, :fail_other ), do: "fail_other"

    def policy_error(conn, "err_generic"),  do: Plug.Conn.assign(conn, :errd, "err_generic_b")
    def policy_error(conn, "err_data_b"),   do: Plug.Conn.assign(conn, :errd, "err_data_b")
    def policy_error(_conn, "invalid"),     do: "invalid"
  end


  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end


  #============================================================================
  # call_policy

  #----------------------------------------------------------------------------
  test "call_policy calls policy handlers in the given order", %{conn: conn} do
    {:ok, conn} = Utils.call_policy([ModA,ModB], conn, :generic)
    assert conn.assigns.found == "mod_a_generic"
    
    {:ok, conn} = Utils.call_policy([ModB,ModA], conn, :generic)
    assert conn.assigns.found == "mod_b_generic"
  end

  #----------------------------------------------------------------------------
  test "call_policy skips nil handlers in the given order", %{conn: conn} do
    {:ok, conn} = Utils.call_policy([nil,ModA,ModB], conn, :generic)
    assert conn.assigns.found == "mod_a_generic"
        
    {:ok, conn} = Utils.call_policy([nil,ModB,ModA], conn, :generic)
    assert conn.assigns.found == "mod_b_generic"
  end

  #----------------------------------------------------------------------------
  test "call_policy finds handler down the chain in the given order", %{conn: conn} do
    {:ok, conn} = Utils.call_policy([ModA,ModB], conn, :mod_a_policy)
    assert conn.assigns.found == "mod_a_policy"

    {:ok, conn} = Utils.call_policy([ModA,nil,ModB], conn, :mod_b_policy)
    assert conn.assigns.found == "mod_b_policy"
  end

  #----------------------------------------------------------------------------
  test "call_policy raises if policy is missing", %{conn: conn} do
    assert_raise PolicyWonk.Enforce.Error, fn ->
      Utils.call_policy([ModA,ModB], conn, :missing)
    end
  end

  #----------------------------------------------------------------------------
  test "call_policy returns conn if :ok", %{conn: conn} do
    assert Utils.call_policy([ModA,ModB], conn, :ok_ok) == {:ok, conn}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns conn if true", %{conn: conn} do
    assert Utils.call_policy([ModA,ModB], conn, :ok_true) == {:ok, conn}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns error data", %{conn: conn} do
    assert Utils.call_policy([ModA,ModB], conn, :fail_data) == {:err, conn, "err_data"}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns nil error data on false, :err, or :error", %{conn: conn} do
    assert Utils.call_policy([ModA,ModB], conn, :fail_false) == {:err, conn, nil}
    assert Utils.call_policy([ModA,ModB], conn, :fail_err) ==   {:err, conn, nil}
    assert Utils.call_policy([ModA,ModB], conn, :fail_error) == {:err, conn, nil}
  end

  #----------------------------------------------------------------------------
  test "call_policy raises on unknown responses", %{conn: conn} do
    assert_raise RuntimeError, fn ->
      Utils.call_policy([ModA,ModB], conn, :fail_other)
    end
  end


  #============================================================================
  # call_policy_error
  #----------------------------------------------------------------------------
  test "call_policy_error calls policy handlers in the given order", %{conn: conn} do
    conn = Utils.call_policy_error([ModA,ModB], conn, "err_generic")
    assert conn.assigns.errd == "err_generic_a"

    conn = Utils.call_policy_error([ModB,ModA], conn, "err_generic")
    assert conn.assigns.errd == "err_generic_b"
  end

  #----------------------------------------------------------------------------
  test "call_policy_error skips nil handlers in the given order", %{conn: conn} do
    conn = Utils.call_policy_error([nil,ModA,ModB], conn, "err_generic")
    assert conn.assigns.errd == "err_generic_a"

    conn = Utils.call_policy_error([nil,ModB,ModA], conn, "err_generic")
    assert conn.assigns.errd == "err_generic_b"
  end

  #----------------------------------------------------------------------------
  test "call_policy_error finds handler down the chain in the given order", %{conn: conn} do
    conn = Utils.call_policy_error([ModA,ModB], conn, "err_data_a")
    assert conn.assigns.errd == "err_data_a"

    conn = Utils.call_policy_error([ModA,nil,ModB], conn, "err_data_b")
    assert conn.assigns.errd == "err_data_b"
  end

  #----------------------------------------------------------------------------
  test "call_policy_error raises if policy is missing", %{conn: conn} do
    assert_raise PolicyWonk.Enforce.Error, fn ->
      Utils.call_policy_error([ModA,ModB], conn, "missing")
    end
  end


  #============================================================================
  # append_truthy

  #----------------------------------------------------------------------------
  test "append_truthy appends a single element to the list" do
    assert Utils.append_truthy([1,2,3], "a") == [1, 2, 3, "a"]
  end

  #----------------------------------------------------------------------------
  test "append_truthy appends a list to a list" do
    assert Utils.append_truthy([1,2,3], ["a", "b", "c"]) == [1, 2, 3, "a", "b", "c"]
  end

  #----------------------------------------------------------------------------
  test "append_truthy returns the original list if element is nil" do
    assert Utils.append_truthy([1,2,3], nil) == [1,2,3]
  end

  #============================================================================
  # get_exists
  @get_exists_map %{
    one: 1,
    sub: %{
      two: 2,
      sub: %{
        three: 3
      }
    }
  }

  #----------------------------------------------------------------------------
  test "get_exists gets top level values" do
    assert Utils.get_exists(@get_exists_map, :one) == 1
    assert Utils.get_exists(@get_exists_map, [:one]) == 1
  end

  #----------------------------------------------------------------------------
  test "get_exists gets nested values" do
    assert Utils.get_exists(@get_exists_map, [:sub, :two]) == 2
    assert Utils.get_exists(@get_exists_map, [:sub, :sub, :three]) == 3
  end

  #----------------------------------------------------------------------------
  test "get_exists returns nil if a value doesn't exist" do
    assert Utils.get_exists(@get_exists_map, :missing) == nil
    assert Utils.get_exists(@get_exists_map, [:missing]) == nil
    assert Utils.get_exists(@get_exists_map, [:sub, :missing]) == nil
    assert Utils.get_exists(@get_exists_map, [:sub, :sub, :missing]) == nil
  end

  #----------------------------------------------------------------------------
  test "get_exists returns nil if a sub map doesn't exist" do
    assert Utils.get_exists(@get_exists_map, [:missing, :two]) == nil
  end
end
