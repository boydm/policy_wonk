defmodule PolicyWonk.EnforceTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Enforce
  doctest PolicyWonk

  #  import IEx

  defmodule ModA do
    use PolicyWonk.Policy
    use PolicyWonk.Enforce

    def policy(_assigns, :a), do: :ok
    def policy(_assigns, :fails), do: {:error, "failed_policy"}

    def policy_error(conn, "failed_policy"), do: Plug.Conn.assign(conn, :errp, "failed_policy")
  end

  # ============================================================================
  # use init
  # --------------------------------------------------------
  test "use init sets up policies with defaults" do
    assert ModA.init(policies: [:a, :b]) == %{policies: [:a, :b], policy_module: ModA}
  end

  # --------------------------------------------------------
  test "use init accepts a single policy" do
    assert ModA.init(policies: :a) == %{policies: [:a], policy_module: ModA}
    assert ModA.init(:a) == %{policies: [:a], policy_module: ModA}
  end

  # --------------------------------------------------------
  test "use init raises on empty policies list" do
    assert_raise PolicyWonk.Enforce.Error, fn -> ModA.init(policies: []) end
  end

  # ============================================================================
  # init

  # --------------------------------------------------------
  test "init sets up policies with defaults" do
    assert Enforce.init(policies: [:a, :b], policy_module: ModA) == %{
             policies: [:a, :b],
             policy_module: ModA
           }
  end

  # --------------------------------------------------------
  test "init accepts a single policy" do
    assert Enforce.init(policies: :a, policy_module: ModA) == %{
             policies: [:a],
             policy_module: ModA
           }
  end

  # --------------------------------------------------------
  test "init raises on empty policies list" do
    assert_raise PolicyWonk.Enforce.Error, fn ->
      Enforce.init(policies: [], policy_module: ModA)
    end
  end

  # ============================================================================
  # call
  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  # --------------------------------------------------------
  test "call uses the requested policy on the requested module", %{conn: conn} do
    opts = %{policy_module: ModA, policies: [:a]}
    %Plug.Conn{halted: false} = Enforce.call(conn, opts)
  end

  # --------------------------------------------------------
  test "call halts the plug chain on a failure", %{conn: conn} do
    opts = %{policy_module: ModA, policies: [:fails]}
    %Plug.Conn{halted: true} = Enforce.call(conn, opts)
  end

  # --------------------------------------------------------
  test "call handles errors after policy failures", %{conn: conn} do
    opts = %{policy_module: ModA, policies: [:fails]}
    conn = Enforce.call(conn, opts)
    assert conn.assigns.errp == "failed_policy"
  end
end
