defmodule PolicyWonk.UtilsTest do
  use ExUnit.Case, async: true
  alias PolicyWonk.Utils
  doctest PolicyWonk

#  import IEx

  defmodule ModA do
    def thingy( :generic ),     do: "generic_a"
    def thingy( :specific_a ),  do: "specific_a"
  end

  defmodule ModB do
    def thingy( :generic ),     do: "generic_b"
    def thingy( :specific_b ),  do: "specific_b"
  end


  #============================================================================
  # call_into_list

  #----------------------------------------------------------------------------
  test "call_into_list calls handlers in right order" do
    assert Utils.call_into_list([ModA,ModB], &(&1.thingy(:generic)) ) == "generic_a"
    assert Utils.call_into_list([ModB,ModA], &(&1.thingy(:generic)) ) == "generic_b"
  end

  #----------------------------------------------------------------------------
  test "call_into_list calls handlers skips nil handlers" do
    assert Utils.call_into_list([nil,ModA,ModB], &(&1.thingy(:generic)) ) == "generic_a"
  end

  #----------------------------------------------------------------------------
  test "call_into_list finds handlers down the list" do
    assert Utils.call_into_list([nil,ModA,nil,ModB], &(&1.thingy(:specific_a)) ) == "specific_a"
    assert Utils.call_into_list([nil,ModA,nil,ModB], &(&1.thingy(:specific_b)) ) == "specific_b"
  end

  #----------------------------------------------------------------------------
  test "call_into_list returns :not_found on missing function" do
    assert Utils.call_into_list([nil,ModA,nil,ModB], &(&1.missing(:generic)) ) == :not_found
  end

  #----------------------------------------------------------------------------
  test "call_into_list returns :not_found on missing match" do
    assert Utils.call_into_list([nil,ModA,nil,ModB], &(&1.thingy(:missing)) ) == :not_found
  end


  #============================================================================
  # build_handlers_msg

  #----------------------------------------------------------------------------
  test "build_handlers_msg build a string with the names of the handlers" do
    assert Utils.build_handlers_msg([nil,ModA,nil,ModB]) ==
      "PolicyWonk.UtilsTest.ModA\nPolicyWonk.UtilsTest.ModB\n"
  end


  #============================================================================
  # append_truthy

  #----------------------------------------------------------------------------
  test "append_truthy appends a single element to the list" do
    assert Utils.append_truthy([1,2,3], "a") == [1, 2, 3, "a"]
  end

  #----------------------------------------------------------------------------
  test "append_truthy appends a list to a list" do
    assert Utils.append_truthy([1,2,3], ["a", "b", "c"]) == [1, 2, 3, "a", "b", "c"]
  end

  #----------------------------------------------------------------------------
  test "append_truthy returns the original list if element is nil" do
    assert Utils.append_truthy([1,2,3], nil) == [1,2,3]
  end


  #============================================================================
  # get_exists
  @get_exists_map %{
    one: 1,
    sub: %{
      two: 2,
      sub: %{
        three: 3
      }
    }
  }

  #----------------------------------------------------------------------------
  test "get_exists gets top level values" do
    assert Utils.get_exists(@get_exists_map, :one) == 1
    assert Utils.get_exists(@get_exists_map, [:one]) == 1
  end

  #----------------------------------------------------------------------------
  test "get_exists gets nested values" do
    assert Utils.get_exists(@get_exists_map, [:sub, :two]) == 2
    assert Utils.get_exists(@get_exists_map, [:sub, :sub, :three]) == 3
  end

  #----------------------------------------------------------------------------
  test "get_exists returns nil if a value doesn't exist" do
    assert Utils.get_exists(@get_exists_map, :missing) == nil
    assert Utils.get_exists(@get_exists_map, [:missing]) == nil
    assert Utils.get_exists(@get_exists_map, [:sub, :missing]) == nil
    assert Utils.get_exists(@get_exists_map, [:sub, :sub, :missing]) == nil
  end

  #----------------------------------------------------------------------------
  test "get_exists returns nil if a sub map doesn't exist" do
    assert Utils.get_exists(@get_exists_map, [:missing, :two]) == nil
  end
end
