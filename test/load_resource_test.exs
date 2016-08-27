defmodule PolicyWonk.LoadResourceTest do
  use ExUnit.Case, async: false
  alias PolicyWonk.LoadResource
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
      {:err, "invalid"}
    end

    #----------------------------------------------------------------------------
    def load_error( conn, "invalid" ) do
      conn
      |> Plug.Conn.put_status(404)
      |> Plug.Conn.halt
    end
  end

  #============================================================================
  # init
  #----------------------------------------------------------------------------
  test "init filters options" do
    assert LoadResource.init(%{loader: ModA}) ==
      %{
        resource_list: [],
        loader: ModA,
        async: false       # From config
      }

  end

  #----------------------------------------------------------------------------
  test "init defaults opts" do
    assert LoadResource.init(%{}) ==
      %{
        resource_list: [],
        loader: nil,
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init converts single policy option to the right map" do
    assert LoadResource.init(:something_to_load) ==
      %{
        resource_list: [:something_to_load],
        loader: nil,
        async: false       # From config
      }
  end

  #----------------------------------------------------------------------------
  test "init preps the resouce list" do
    assert LoadResource.init([:thing_a, nil, "thing_a", :thing_b]) ==
      %{
        resource_list: [:thing_a, :thing_b],
        loader: nil,
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
        resource_list: [:thing_a, :thing_b],
        loader: ModA,
        async: false       # From config
      }
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.thing_a == "thing_a"
    assert conn.assigns.thing_b == "thing_b"
  end

  #----------------------------------------------------------------------------
  test "call loads the resource into the conn's assigns (async: true)", %{conn: conn} do
    opts = %{
        resource_list: [:thing_a, :thing_b],
        loader: ModA,
        async: true       # From config
      }
    conn = LoadResource.call(conn, opts)
    assert conn.assigns.thing_a == "thing_a"
    assert conn.assigns.thing_b == "thing_b"
  end

  #----------------------------------------------------------------------------
  test "call handles load errors", %{conn: conn} do
    opts = %{
        resource_list: [:invalid],
        loader: ModA,
        async: true       # From config
      }
    conn = LoadResource.call(conn, opts)
    assert conn.status == 404
  end

end