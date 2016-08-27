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
  end

  #============================================================================
  # call_policy

  #----------------------------------------------------------------------------
  test "call_policy calls policy handlers in the given order" do
    conn = Plug.Test.conn(:get, "/abc")

    {:ok, conn} = Utils.call_policy([ModA,ModB], conn, :generic)
    assert conn.assigns.found == "mod_a_generic"
    
    {:ok, conn} = Utils.call_policy([ModB,ModA], conn, :generic)
    assert conn.assigns.found == "mod_b_generic"
  end

  #----------------------------------------------------------------------------
  test "call_policy skips nil handlers in the given order" do
    conn = Plug.Test.conn(:get, "/abc")

    {:ok, conn} = Utils.call_policy([nil,ModA,ModB], conn, :generic)
    assert conn.assigns.found == "mod_a_generic"
        
    {:ok, conn} = Utils.call_policy([nil,ModB,ModA], conn, :generic)
    assert conn.assigns.found == "mod_b_generic"
  end

  #----------------------------------------------------------------------------
  test "call_policy finds handler down the chain in the given order" do
    conn = Plug.Test.conn(:get, "/abc")

    {:ok, conn} = Utils.call_policy([ModA,ModB], conn, :mod_a_policy)
    assert conn.assigns.found == "mod_a_policy"

    {:ok, conn} = Utils.call_policy([ModA,nil,ModB], conn, :mod_b_policy)
    assert conn.assigns.found == "mod_b_policy"
  end

  #----------------------------------------------------------------------------
  test "call_policy raises if policy is missing" do
    conn = Plug.Test.conn(:get, "/abc")
    assert_raise PolicyWonk.Enforce.Error, fn ->
      Utils.call_policy([ModA,ModB], conn, :missing)
    end
  end

  #----------------------------------------------------------------------------
  test "call_policy returns conn if :ok" do
    conn = Plug.Test.conn(:get, "/abc")
    assert Utils.call_policy([ModA,ModB], conn, :ok_ok) == {:ok, conn}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns conn if true" do
    conn = Plug.Test.conn(:get, "/abc")
    assert Utils.call_policy([ModA,ModB], conn, :ok_true) == {:ok, conn}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns error data" do
    conn = Plug.Test.conn(:get, "/abc")
    assert Utils.call_policy([ModA,ModB], conn, :fail_data) == {:err, conn, "err_data"}
  end

  #----------------------------------------------------------------------------
  test "call_policy returns nil error data on false, :err, or :error" do
    conn = Plug.Test.conn(:get, "/abc")
    assert Utils.call_policy([ModA,ModB], conn, :fail_false) == {:err, conn, nil}
    assert Utils.call_policy([ModA,ModB], conn, :fail_err) ==   {:err, conn, nil}
    assert Utils.call_policy([ModA,ModB], conn, :fail_error) == {:err, conn, nil}
  end

  #----------------------------------------------------------------------------
  test "call_policy raises on unknown responses" do
    conn = Plug.Test.conn(:get, "/abc")
    assert_raise RuntimeError, fn ->
      Utils.call_policy([ModA,ModB], conn, :fail_other)
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
