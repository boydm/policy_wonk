defmodule PolicyWonk.ResourceTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Resource
  doctest PolicyWonk

  #  import IEx

  defmodule ModA do
    use PolicyWonk.Load
    use PolicyWonk.Resource

    def resource(_conn, :a, _params) do
      {:ok, :thing_a, "thing_a"}
    end

    def resource(_conn, :b, _params) do
      {:ok, :thing_b, "thing_b"}
    end

    def resource(_conn, :fails, _params) do
      {:error, "fails"}
    end

    def resource_error(conn, "fails") do
      conn
      |> Plug.Conn.assign(:errp, "failed_resource")
      |> Plug.Conn.put_status(404)
      |> Plug.Conn.halt()
    end
  end

  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  # ============================================================================
  # use load

  # --------------------------------------------------------
  test "use load uses the requested resource on the requested module - sync", %{conn: conn} do
    %Plug.Conn{halted: false, assigns: %{thing_a: _, thing_b: _}} = ModA.load(conn, [:a, :b])
    %Plug.Conn{halted: false, assigns: %{thing_a: _}} = ModA.load(conn, :a)
  end

  # --------------------------------------------------------
  test "use load uses the requested resource on the requested module - async", %{conn: conn} do
    %Plug.Conn{halted: false, assigns: %{thing_a: _, thing_b: _}} =
      ModA.load(conn, [:a, :b], true)

    %Plug.Conn{halted: false, assigns: %{thing_a: _}} = ModA.load(conn, :a, true)
  end

  # --------------------------------------------------------
  test "use load halts the plug chain on a failure", %{conn: conn} do
    %Plug.Conn{halted: true} = ModA.load(conn, [:fails])
    %Plug.Conn{halted: true} = ModA.load(conn, :fails)
    %Plug.Conn{halted: true} = ModA.load(conn, [:a, :fails])
  end

  # --------------------------------------------------------
  test "use load handles errors after resource failures", %{conn: conn} do
    conn = ModA.load(conn, [:fails])
    assert conn.assigns.errp == "failed_resource"
  end

  # ============================================================================
  # load

  # --------------------------------------------------------
  test "enforce uses the requested resource on the requested module - sync", %{conn: conn} do
    %Plug.Conn{halted: false, assigns: %{thing_a: _, thing_b: _}} =
      Resource.load(conn, ModA, [:a, :b])

    %Plug.Conn{halted: false, assigns: %{thing_a: _}} = Resource.load(conn, ModA, :a)
  end

  # --------------------------------------------------------
  test "load uses the requested resource on the requested module - async", %{conn: conn} do
    %Plug.Conn{halted: false, assigns: %{thing_a: _, thing_b: _}} =
      Resource.load(conn, ModA, [:a, :b], true)

    %Plug.Conn{halted: false, assigns: %{thing_a: _}} = Resource.load(conn, ModA, :a, true)
  end

  # --------------------------------------------------------
  test "load halts the plug chain on a failure", %{conn: conn} do
    %Plug.Conn{halted: true} = Resource.load(conn, ModA, [:fails])
    %Plug.Conn{halted: true} = Resource.load(conn, ModA, :fails)
    %Plug.Conn{halted: true} = Resource.load(conn, ModA, [:a, :fails])
  end

  # --------------------------------------------------------
  test "load handles errors after resource failures", %{conn: conn} do
    conn = Resource.load(conn, ModA, [:fails])
    assert conn.assigns.errp == "failed_resource"
  end

  # ============================================================================
  # use load!

  # --------------------------------------------------------
  test "use load! uses the requested resource on the requested module", %{conn: conn} do
    assert ModA.load!(conn, [:a, :b]) == [a: "thing_a", b: "thing_b"]
    assert ModA.load!(conn, :a) == "thing_a"
  end

  # --------------------------------------------------------
  test "use load! raises on a failure", %{conn: conn} do
    assert_raise PolicyWonk.Resource.Error, fn -> ModA.load!(conn, [:fails]) end
    assert_raise PolicyWonk.Resource.Error, fn -> ModA.load!(conn, :fails) end
    assert_raise PolicyWonk.Resource.Error, fn -> ModA.load!(conn, [:a, :fails]) end
  end

  # ============================================================================
  # load!

  # --------------------------------------------------------
  test "load! uses the requested policy on the requested module", %{conn: conn} do
    assert Resource.load!(conn, ModA, [:a, :b]) == [a: "thing_a", b: "thing_b"]
    assert Resource.load!(conn, ModA, :a) == "thing_a"
  end

  # --------------------------------------------------------
  test "load! raises on a failure", %{conn: conn} do
    assert_raise PolicyWonk.Resource.Error, fn -> Resource.load!(conn, ModA, [:fails]) end
    assert_raise PolicyWonk.Resource.Error, fn -> Resource.load!(conn, ModA, :fails) end
    assert_raise PolicyWonk.Resource.Error, fn -> Resource.load!(conn, ModA, [:a, :fails]) end
  end
end
