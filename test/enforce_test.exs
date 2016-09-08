defmodule PolicyWonk.EnforceTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Enforce
  doctest PolicyWonk

#  import IEx

  defmodule ModA do
    def policy( _assigns, :suceeds_a ),        do: :ok
    def policy( _assigns, :fails ),            do: "failed_policy"

    def policy_error(conn, "failed_policy"),  do: Plug.Conn.assign(conn, :errp, "failed_policy")
    def policy_error(_conn, "invalid"),       do: "invalid"
  end

  defmodule ModController do
    def policy( _assigns, :suceeds_c ) do
      :ok
    end
  end

  defmodule ModRouter do
    def policy( _assigns, :suceeds_r ) do
      :ok
    end
  end

  #============================================================================
  # init
  #----------------------------------------------------------------------------
  test "init sets up full options" do
    assert Enforce.init(%{
      policies: [:a,:b],
      handler: ModA,
      invalid: "invalid"
    }) == %{policies: [:a,:b], handler: ModA}
  end

  #----------------------------------------------------------------------------
  test "init handles policies only partial opts" do
    assert Enforce.init(%{
      policies: [:a,:b]
    }) == %{policies: [:a,:b], handler: nil}
  end

  #----------------------------------------------------------------------------
  test "init sets single policy into opts" do
    assert Enforce.init(:policy_name) == 
      %{policies: [:policy_name], handler: nil}
  end

  #----------------------------------------------------------------------------
  test "init sets single policy (in opts) into a list" do
    assert Enforce.init(%{policies: :a}) == 
      %{policies: [:a], handler: nil}
  end

  #----------------------------------------------------------------------------
  test "init sets policy list into opts" do
    assert Enforce.init([:policy_a, :policy_b]) == 
      %{policies: [:policy_a, :policy_b], handler: nil}
  end

  #----------------------------------------------------------------------------
  test "init raises on empty policies in opts" do
    assert_raise PolicyWonk.Enforce, fn -> Enforce.init(%{policies: []}) end
  end

  #----------------------------------------------------------------------------
  test "init raises on empty policies list" do
    assert_raise PolicyWonk.Enforce, fn -> Enforce.init([]) end
  end



  #============================================================================
  # call
  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #----------------------------------------------------------------------------
  test "call uses policy on global (config) policies module", %{conn: conn} do
    opts = %{handler: nil, policies: [:from_config]}
    Enforce.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call uses policy on the requested module - generic conn", %{conn: conn} do
    opts = %{handler: ModA, policies: [:suceeds_a]}
    Enforce.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call uses policy on (optional) controller", %{conn: conn} do
    opts = %{handler: nil, policies: [:suceeds_c]}
    conn = Map.put(conn, :private, %{phoenix_controller: ModController})
    Enforce.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call uses policy on (optional) router", %{conn: conn} do
    opts = %{handler: nil, policies: [:suceeds_r]}
    conn = Map.put(conn, :private, %{phoenix_router: ModRouter})
    Enforce.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call handles errors after policy failures", %{conn: conn} do
    opts = %{handler: ModA, policies: [:fails]}
    conn = Enforce.call(conn, opts)
    assert conn.assigns.errp == "failed_policy"
  end



  #============================================================================
  # evaluate_policies

  #----------------------------------------------------------------------------
  test "evaluate_policies calls policy handlers", %{conn: conn} do
    assert Enforce.evaluate_policies([ModA], conn, [:suceeds_a]) == :ok
  end

  #----------------------------------------------------------------------------
  test "evaluate_policies returns error data", %{conn: conn} do
    assert Enforce.evaluate_policies([ModA], conn, [:fails]) == "failed_policy"
  end

  #----------------------------------------------------------------------------
  test "evaluate_policies skips nil handlers", %{conn: conn} do
    assert Enforce.evaluate_policies([nil, ModA], conn, [:suceeds_a]) == :ok
  end

  #----------------------------------------------------------------------------
  test "evaluate_policies raises if policy not found", %{conn: conn} do
    assert_raise PolicyWonk.Enforce, fn ->
      Enforce.evaluate_policies([ModA], conn, [:missing])
    end
  end


end
















