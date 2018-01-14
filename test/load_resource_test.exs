defmodule PolicyWonk.LoadResourceTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.LoadResource
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
    def load_resource(_conn, :invalid, _params) do
      {:error, "invalid"}
    end

    def load_error( conn, "invalid" ) do
      conn
      |> Plug.Conn.put_status(404)
      |> Plug.Conn.halt
    end
  end

  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #============================================================================
  # use init
  #--------------------------------------------------------
  test "use init sets up policies with defaults" do
    assert ModA.init( resources: [:a,:b] ) ==
      %{resources: [:a,:b], resource_module: ModA, async: false}
  end

  #--------------------------------------------------------
  test "use init accepts a single policy" do
    assert ModA.init( resources: :a ) == %{resources: [:a], resource_module: ModA, async: false}

    assert ModA.init( :a ) == %{resources: [:a], resource_module: ModA, async: false}
  end

  #----------------------------------------------------------------------------
  test "use init raises on empty resources list" do
    assert_raise PolicyWonk.LoadResource.Error, fn -> ModA.init( resources: [] ) end
  end

  #============================================================================
  # init

  #--------------------------------------------------------
  test "init sets up policies with defaults" do
    assert LoadResource.init( resources: [:a,:b], resource_module: ModA ) == %{resources: [:a,:b], resource_module: ModA, async: false}
  end

  #--------------------------------------------------------
  test "init accepts a single policy" do
    assert LoadResource.init( resources: :a, resource_module: ModA ) == %{resources: [:a], resource_module: ModA, async: false}
  end

  #--------------------------------------------------------
  test "init raises on empty policies list" do
    assert_raise PolicyWonk.LoadResource.Error, fn -> LoadResource.init( resources: [], resource_module: ModA ) end
  end


  #============================================================================
  # use call

  #--------------------------------------------------------
  test "use call uses the requested loader on the requested module", %{conn: conn} do
    opts = %{resources: [:a], resource_module: ModA, async: false}
    %Plug.Conn{halted: false} = ModA.call(conn, opts)
  end

  #--------------------------------------------------------
  test "use call halts the plug chain on a failure", %{conn: conn} do
    opts = %{resources: [:invalid], resource_module: ModA, async: false}
    %Plug.Conn{halted: true} = ModA.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "use call handles load errors", %{conn: conn} do
    opts = %{resources: [:invalid], resource_module: ModA, async: false}
    conn = ModA.call(conn, opts)
    assert conn.status == 404
  end


  #============================================================================
  # call

  #--------------------------------------------------------
  test "call uses the requested loader on the requested module", %{conn: conn} do
    opts = %{resources: [:a], resource_module: ModA, async: false}
    %Plug.Conn{halted: false} = LoadResource.call(conn, opts)
  end

  #--------------------------------------------------------
  test "call halts the plug chain on a failure", %{conn: conn} do
    opts = %{resources: [:invalid], resource_module: ModA, async: false}
    %Plug.Conn{halted: true} = LoadResource.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call handles load errors", %{conn: conn} do
    opts = %{resources: [:invalid], resource_module: ModA, async: false}
    conn = LoadResource.call(conn, opts)
    assert conn.status == 404
  end

end
