defmodule PolicyWonk.LoaderTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Loader
  doctest PolicyWonk

#  import IEx


  defmodule ModA do
    use PolicyWonk.LoadResource
    use PolicyWonk.Loader

    def load_resource(_conn, :a, _params) do
      {:ok, :thing_a, "thing_a"}
    end
    def load_resource(_conn, :b, _params) do
      {:ok, :thing_b, "thing_b"}
    end
    def load_resource(_conn, :fails, _params) do
      {:error, "fails"}
    end

    def load_error( conn, "fails" ) do
      conn
      |> Plug.Conn.assign(:errp, "failed_resource")
      |> Plug.Conn.put_status(404)
      |> Plug.Conn.halt
    end
  end

  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #============================================================================
  # use load

  #--------------------------------------------------------
  test "use load uses the requested policy on the requested module - sync", %{conn: conn} do
    %Plug.Conn{halted: false, assigns: %{thing_a: _, thing_b: _}} = ModA.load(conn, [:a,:b])
    %Plug.Conn{halted: false, assigns: %{thing_a: _}} = ModA.load(conn, :a)
  end

  #--------------------------------------------------------
  test "use load uses the requested policy on the requested module - async", %{conn: conn} do
    %Plug.Conn{halted: false, assigns: %{thing_a: _, thing_b: _}} = ModA.load(conn, [:a,:b], true)
    %Plug.Conn{halted: false, assigns: %{thing_a: _}} = ModA.load(conn, :a, true)
  end

  #--------------------------------------------------------
  test "use load halts the plug chain on a failure", %{conn: conn} do
    %Plug.Conn{halted: true} = ModA.load(conn, [:fails])
    %Plug.Conn{halted: true} = ModA.load(conn, :fails)
    %Plug.Conn{halted: true} = ModA.load(conn, [:a, :fails])
  end

  #--------------------------------------------------------
  test "use load handles errors after policy failures", %{conn: conn} do
    conn = ModA.load(conn, [:fails])
    assert conn.assigns.errp == "failed_resource"
  end

  #============================================================================
  # load

  #--------------------------------------------------------
  test "enforce uses the requested policy on the requested module - sync", %{conn: conn} do
    %Plug.Conn{halted: false, assigns: %{thing_a: _, thing_b: _}} = Loader.load(conn, ModA, [:a,:b])
    %Plug.Conn{halted: false, assigns: %{thing_a: _}} = Loader.load(conn, ModA, :a)
  end

  #--------------------------------------------------------
  test "load uses the requested policy on the requested module - async", %{conn: conn} do
    %Plug.Conn{halted: false, assigns: %{thing_a: _, thing_b: _}} = Loader.load(conn, ModA, [:a,:b], true)
    %Plug.Conn{halted: false, assigns: %{thing_a: _}} = Loader.load(conn, ModA, :a, true)
  end

  #--------------------------------------------------------
  test "enforce halts the plug chain on a failure", %{conn: conn} do
    %Plug.Conn{halted: true} = Loader.load(conn, ModA, [:fails])
    %Plug.Conn{halted: true} = Loader.load(conn, ModA, :fails)
    %Plug.Conn{halted: true} = Loader.load(conn, ModA, [:a, :fails])
  end

  #--------------------------------------------------------
  test "enforce handles errors after policy failures", %{conn: conn} do
    conn = Loader.load(conn, ModA, [:fails])
    assert conn.assigns.errp == "failed_resource"
  end



  #============================================================================
  # use load!

  #--------------------------------------------------------
  test "use load! uses the requested policy on the requested module", %{conn: conn} do
    assert ModA.load!(conn, [:a,:b]) == [a: "thing_a", b: "thing_b"]
    assert ModA.load!(conn, :a) == "thing_a"
  end

  #--------------------------------------------------------
  test "use load! raises on a failure", %{conn: conn} do
    assert_raise PolicyWonk.Loader.Error, fn -> ModA.load!(conn, [:fails]) end
    assert_raise PolicyWonk.Loader.Error, fn -> ModA.load!(conn, :fails) end
    assert_raise PolicyWonk.Loader.Error, fn -> ModA.load!(conn, [:a, :fails]) end
  end

  #============================================================================
  # load!

  #--------------------------------------------------------
  test "load! uses the requested policy on the requested module", %{conn: conn} do
    assert Loader.load!(conn, ModA, [:a,:b]) == [a: "thing_a", b: "thing_b"]
    assert Loader.load!(conn, ModA, :a) == "thing_a"
  end

  #--------------------------------------------------------
  test "load! raises on a failure", %{conn: conn} do
    assert_raise PolicyWonk.Loader.Error, fn -> Loader.load!(conn, ModA, [:fails]) end
    assert_raise PolicyWonk.Loader.Error, fn -> Loader.load!(conn, ModA, :fails) end
    assert_raise PolicyWonk.Loader.Error, fn -> Loader.load!(conn, ModA, [:a, :fails]) end
  end

end
