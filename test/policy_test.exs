defmodule PolicyWonk.PolicyTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Policy
  doctest PolicyWonk

  #  import IEx

  defmodule ModA do
    use PolicyWonk.Policy

    def policy(_assigns, :a), do: :ok
    def policy(_assigns, :fails), do: {:error, "failed_policy"}

    def policy_error(conn, "failed_policy"), do: Plug.Conn.assign(conn, :errp, "failed_policy")
  end

  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  # ============================================================================
  # use enforce

  # --------------------------------------------------------
  test "use enforce uses the requested policy on the requested module", %{conn: conn} do
    %Plug.Conn{halted: false} = ModA.enforce(conn, [:a])
    %Plug.Conn{halted: false} = ModA.enforce(conn, :a)
  end

  # --------------------------------------------------------
  test "use enforce halts the plug chain on a failure", %{conn: conn} do
    %Plug.Conn{halted: true} = ModA.enforce(conn, [:fails])
    %Plug.Conn{halted: true} = ModA.enforce(conn, :fails)
    %Plug.Conn{halted: true} = ModA.enforce(conn, [:a, :fails])
  end

  # --------------------------------------------------------
  test "use enforce handles errors after policy failures", %{conn: conn} do
    conn = ModA.enforce(conn, [:fails])
    assert conn.assigns.errp == "failed_policy"
  end

  # ============================================================================
  # enforce

  # --------------------------------------------------------
  test "enforce uses the requested policy on the requested module", %{conn: conn} do
    %Plug.Conn{halted: false} = Policy.enforce(conn, ModA, [:a])
    %Plug.Conn{halted: false} = Policy.enforce(conn, ModA, :a)
  end

  # --------------------------------------------------------
  test "enforce halts the plug chain on a failure", %{conn: conn} do
    %Plug.Conn{halted: true} = Policy.enforce(conn, ModA, [:fails])
    %Plug.Conn{halted: true} = Policy.enforce(conn, ModA, :fails)
    %Plug.Conn{halted: true} = Policy.enforce(conn, ModA, [:a, :fails])
  end

  # --------------------------------------------------------
  test "enforce handles errors after policy failures", %{conn: conn} do
    conn = Policy.enforce(conn, ModA, [:fails])
    assert conn.assigns.errp == "failed_policy"
  end

  # ============================================================================
  # use enforce!

  # --------------------------------------------------------
  test "use enforce! uses the requested policy on the requested module", %{conn: conn} do
    assert ModA.enforce!(conn, [:a]) == :ok
    assert ModA.enforce!(conn, :a) == :ok
  end

  # --------------------------------------------------------
  test "use enforce! raises on a failure", %{conn: conn} do
    assert_raise PolicyWonk.Policy.Error, fn -> ModA.enforce!(conn, [:fails]) end
    assert_raise PolicyWonk.Policy.Error, fn -> ModA.enforce!(conn, :fails) end
    assert_raise PolicyWonk.Policy.Error, fn -> ModA.enforce!(conn, [:a, :fails]) end
  end

  # ============================================================================
  # enforce!

  # --------------------------------------------------------
  test "enforce! uses the requested policy on the requested module", %{conn: conn} do
    assert Policy.enforce!(conn, ModA, [:a]) == :ok
    assert Policy.enforce!(conn, ModA, :a) == :ok
  end

  # --------------------------------------------------------
  test "enforce! raises on a failure", %{conn: conn} do
    assert_raise PolicyWonk.Policy.Error, fn -> Policy.enforce!(conn, ModA, [:fails]) end
    assert_raise PolicyWonk.Policy.Error, fn -> Policy.enforce!(conn, ModA, :fails) end
    assert_raise PolicyWonk.Policy.Error, fn -> Policy.enforce!(conn, ModA, [:a, :fails]) end
  end

  # ============================================================================
  # use authorized?

  # --------------------------------------------------------
  test "use authorized?! returns true on policy success", %{conn: conn} do
    assert ModA.authorized?(conn, [:a]) == true
    assert ModA.authorized?(conn, :a) == true
  end

  # --------------------------------------------------------
  test "use authorized?! returns true on policy success when not using a conn", %{conn: conn} do
    authorization_context = %{assigns: conn.assigns}
    assert ModA.authorized?(authorization_context, [:a]) == true
    assert ModA.authorized?(authorization_context, :a) == true
  end

  # --------------------------------------------------------
  test "use authorized? raises on a failure", %{conn: conn} do
    assert ModA.authorized?(conn, [:fails]) == false
    assert ModA.authorized?(conn, :fails) == false
    assert ModA.authorized?(conn, [:a, :fails]) == false
  end

  # ============================================================================
  # authorized?

  # --------------------------------------------------------
  test "authorized? uses the requested policy on the requested module", %{conn: conn} do
    assert Policy.authorized?(conn, ModA, [:a]) == true
    assert Policy.authorized?(conn, ModA, :a) == true
  end

  # --------------------------------------------------------
  test "authorized? uses the requested policy on the requested module when not using a conn", %{conn: conn} do
    authorization_context = %{assigns: conn.assigns}
    assert Policy.authorized?(authorization_context, ModA, [:a]) == true
    assert Policy.authorized?(authorization_context, ModA, :a) == true
  end

  # --------------------------------------------------------
  test "authorized? raises on a failure", %{conn: conn} do
    assert Policy.authorized?(conn, ModA, [:fails]) == false
    assert Policy.authorized?(conn, ModA, :fails) == false
    assert Policy.authorized?(conn, ModA, [:a, :fails]) == false
  end
end
