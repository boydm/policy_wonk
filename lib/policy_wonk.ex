defmodule PolicyWonk do
@moduledoc """
## Summary

PolicyWonk is a lightweight authorization tool for use with any Plug or Phoenix application.
Tools such as comeonin or Guardian are mostly about authentication. PolicyWonk is about
authorization, which is deciding what a user can do after they’ve been authenticated.

PolicyWonk provides two main plugs. One loads resources into the conn's assigns map. The other
evaluates policies against those resources and decides if the action can be taken.

It is important that these are both implented as plugs. That way, authorization decisions
can be made before controller actions are called. It also means loaders and policies can
be used from your router, before the controller is even chosen.

"""
end