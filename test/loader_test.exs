defmodule PolicyWonk.LoadResourceTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Loader
  doctest PolicyWonk

#  import IEx

  defmodule ModA do
    def load_resource(_conn, :thing_a, _params) do
      {:ok, "thing_a"}
    end
    def load_resource(_conn, :thing_b, _params) do
      {:ok, "thing_b"}
    end
    def load_resource(_conn, :invalid, _params) do
      {:error, "invalid"}
    end
    def load_resource(_conn, :bad_wolf, _params) do
      {:error, "bad_wolf"}
    end

    def load_error( conn, "invalid" ) do
      conn
      |> Plug.Conn.put_status(404)
      |> Plug.Conn.halt
    end
  end

  defmodule ModController do
    def load_resource(_conn, :thing_a, _params) do
      {:ok, "controller_thing_a"}
    end
  end

  defmodule ModRouter do
    def load_resource(_conn, :thing_a, _params) do
      {:ok, "router_thing_a"}
    end
  end

  @conn_controller %{
    private: %{
      phoenix_controller: :controller,
      phoenix_router:     :router,
      phoenix_action:     :action
    }
  }

  @conn_router %{
    private: %{
      phoenix_router:     :router,
    }
  }

  @conn_empty %{}



  #============================================================================
  # init
  #----------------------------------------------------------------------------
  test "init accepts a full opts map" do
    assert Loader.init(%{loaders: [:something_to_load], handler: "handler", async: true}) ==
      %{
        loaders: [:something_to_load],
        handler: "handler",
        async: true       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a partial map of loaders" do
    assert Loader.init(%{loaders: [:something_to_load, :another_to_load]}) ==
      %{
        loaders: [:something_to_load, :another_to_load],
        handler: nil,
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a partial map of loaders and handler" do
    assert Loader.init(%{loaders: [:something_to_load], handler: "handler"}) ==
      %{
        loaders: [:something_to_load],
        handler: "handler",
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a partial map of loaders and async" do
    assert Loader.init(%{loaders: [:something_to_load], async: true}) ==
      %{
        loaders: [:something_to_load],
        handler: nil,
        async: true       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init accepts a loader list" do
    assert Loader.init([:something_to_load, :another_to_load]) ==
      %{
        loaders: [:something_to_load, :another_to_load],
        handler: nil,
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init converts single loader into a loader list" do
    assert Loader.init(:something_to_load) ==
      %{
        loaders: [:something_to_load],
        handler: nil,
        async: false       # From config
      }
  end



  #============================================================================
  # call

  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #----------------------------------------------------------------------------
  test "call loads the resource into the conn's assigns (async: false)", %{conn: conn} do
    opts = %{
        loaders: [:thing_a, :thing_b],
        handler: ModA,
        async: false       # From config
      }
    conn = Loader.call(conn, opts)
    assert conn.assigns.thing_a == "thing_a"
    assert conn.assigns.thing_b == "thing_b"
  end

  #----------------------------------------------------------------------------
  test "call loads the resource into the conn's assigns (async: true)", %{conn: conn} do
    opts = %{
        loaders: [:thing_a, :thing_b],
        handler: ModA,
        async: true       # From config
      }
    conn = Loader.call(conn, opts)
    assert conn.assigns.thing_a == "thing_a"
    assert conn.assigns.thing_b == "thing_b"
  end

  #----------------------------------------------------------------------------
  test "call uses loader on (optional) controller", %{conn: conn} do
    opts = %{
        loaders: [:thing_a],
        handler: nil,
        async: false       # From config
      }
    conn = Map.put(conn, :private, %{phoenix_controller: ModController})
    conn = Loader.call(conn, opts)
    assert conn.assigns.thing_a == "controller_thing_a"
  end

  #----------------------------------------------------------------------------
  test "call uses loader on (optional) router", %{conn: conn} do
    opts = %{
        loaders: [:thing_a],
        handler: nil,
        async: false       # From config
      }
    conn = Map.put(conn, :private, %{phoenix_router: ModRouter})
    conn = Loader.call(conn, opts)
    assert conn.assigns.thing_a == "router_thing_a"
  end

  #----------------------------------------------------------------------------
  test "call uses loader set by config", %{conn: conn} do
    opts = %{
        loaders: [:from_config],
        handler: nil,
        async: false       # From config
      }
    conn = Loader.call(conn, opts)
    assert conn.assigns.from_config == "from_config"
  end


  #----------------------------------------------------------------------------
  test "call handles load errors", %{conn: conn} do
    opts = %{
        loaders: [:invalid],
        handler: ModA,
        async: true       # From config
      }
    conn = Loader.call(conn, opts)
    assert conn.status == 404
  end

end