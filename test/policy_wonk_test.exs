defmodule PolicyWonkTest do
  use ExUnit.Case, async: false
  use PolicyWonk
  doctest PolicyWonk

  # internal policies to test against
  def policy(_conn, :valid),   do: true
  def policy(_conn, :invalid), do: false

  setup do
    %{conn: Plug.Test.conn(:get, "/abc")}
  end

  #============================================================================
  # authorized?
  #----------------------------------------------------------------------------
  test "authorized? passes if conditions are valid", %{conn: conn} do
    assert authorized?(conn, :valid) == true
  end

  #----------------------------------------------------------------------------
  test "authorized? fails if conditions are invalid", %{conn: conn} do
    assert authorized?(conn, :invalid) == false
  end

  #----------------------------------------------------------------------------
  test "authorized? uses the config policies", %{conn: conn} do
    assert authorized?(conn, :from_config) == true
  end

end