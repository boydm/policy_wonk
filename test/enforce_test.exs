defmodule PolicyWonk.EnforceTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Enforce
  doctest PolicyWonk

#  import IEx

  defmodule ModA do
    def policy( _assigns, :suceeds_a ),        do: :ok
    def policy( _assigns, %{thing1: _one, thing2: _two} ),        do: :ok
    def policy( _assigns, :fails ),            do: "failed_policy"
    def policy( _assigns, :raises ),            do: inspect( :something, :bad_argument )

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
  test "init sets up policies with defaults" do
    assert Enforce.init(%{
      policies: [:a,:b]
    }) == %{policies: [:a,:b], module: nil, otp_app: :policy_wonk}
  end

  #----------------------------------------------------------------------------
  test "init sets up policies a named otp app" do
    assert Enforce.init(%{
      policies: [:a,:b],
      otp_app: :test_app
    }) == %{policies: [:a,:b], module: nil, otp_app: :test_app}
  end

  #----------------------------------------------------------------------------
  test "init sets single policy into opts" do
    assert Enforce.init(:policy_name) ==  %{policies: [:policy_name], module: nil, otp_app: :policy_wonk}
  end

  #----------------------------------------------------------------------------
  test "init sets single policy (in opts) into a list" do
    assert Enforce.init(%{policies: :a}) == 
      %{policies: [:a], module: nil, otp_app: :policy_wonk}
  end

  #----------------------------------------------------------------------------
  test "accepts map as a policy" do
    assert Enforce.init(%{thing1: "one", thing2: "two"}) == 
      %{policies: [%{thing1: "one", thing2: "two"}], module: nil, otp_app: :policy_wonk}
  end

  #----------------------------------------------------------------------------
  test "init sets policy list into opts" do
    assert Enforce.init([:policy_a, :policy_b]) == 
      %{policies: [:policy_a, :policy_b], module: nil, otp_app: :policy_wonk}
  end

  #----------------------------------------------------------------------------
  test "init sets up full options" do
    assert Enforce.init(%{
      policies: [:a,:b],
      module: ModA,
      otp_app: :test_app
    }) == %{policies: [:a,:b], module: ModA, otp_app: :test_app}
  end

  #----------------------------------------------------------------------------
  test "init raises on empty policies in opts" do
    assert_raise PolicyWonk.Enforce.PolicyError, fn -> Enforce.init(%{policies: []}) end
  end

  #----------------------------------------------------------------------------
  test "init raises on empty policies list" do
    assert_raise PolicyWonk.Enforce.PolicyError, fn -> Enforce.init([]) end
  end



  #============================================================================
  # call
  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #----------------------------------------------------------------------------
  test "call uses policy on global (config) policies module", %{conn: conn} do
    opts = %{module: nil, policies: [:from_config], otp_app: :policy_wonk}
    Enforce.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call uses policy on the requested module - generic conn", %{conn: conn} do
    opts = %{module: ModA, policies: [:suceeds_a], otp_app: :policy_wonk}
    Enforce.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call uses policy on (optional) controller", %{conn: conn} do
    opts = %{module: nil, policies: [:suceeds_c], otp_app: :policy_wonk}
    conn = Map.put(conn, :private, %{phoenix_controller: ModController})
    Enforce.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call uses policy on (optional) router", %{conn: conn} do
    opts = %{module: nil, policies: [:suceeds_r], otp_app: :policy_wonk}
    conn = Map.put(conn, :private, %{phoenix_router: ModRouter})
    Enforce.call(conn, opts)
  end

  #----------------------------------------------------------------------------
  test "call handles errors after policy failures", %{conn: conn} do
    opts = %{module: ModA, policies: [:fails], otp_app: :policy_wonk}
    conn = Enforce.call(conn, opts)
    assert conn.assigns.errp == "failed_policy"
  end

  #----------------------------------------------------------------------------
  test "call raises if policy not found", %{conn: conn} do
    opts = %{module: ModA, policies: [:missing], otp_app: :policy_wonk}
    assert_raise PolicyWonk.Enforce.PolicyError, fn ->
      Enforce.call(conn, opts)
    end
  end

  #----------------------------------------------------------------------------
  test "call surfaces error raised inside policy", %{conn: conn} do
    opts = %{module: ModA, policies: [:raises], otp_app: :policy_wonk}
    assert_raise FunctionClauseError, fn ->
      Enforce.call(conn, opts)
    end
  end

  #----------------------------------------------------------------------------
  test "call works with a map as a policy", %{conn: conn} do
    opts = %{module: ModA, policies: [%{thing1: "one", thing2: "two"}], otp_app: :policy_wonk}
    Enforce.call(conn, opts)
  end

end
















