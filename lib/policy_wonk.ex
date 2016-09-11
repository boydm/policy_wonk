defmodule PolicyWonk do
@moduledoc """

A lightweight authorization and resource loading tool for use with any Plug or Phoenix application.

## Examples

In a router:

      pipeline :browser_session do
        plug PolicyWonk.LoadResource, :current_user
        plug PolicyWonk.Enforce, :current_user
      end
      
      pipeline :admin do
        plug PolicyWonk.Enforce, {:user_permission, "admin"}
      end

In a controller:

      plug PolicyWonk.Enforce, {:user_permission, "admin_content"}
      plug PolicyWonk.EnforceAction

## Authentication vs. Authorization


[Authentication (Auth-N)](https://en.wikipedia.org/wiki/Authentication) is the process of proving that a user or other entity is who/what it claims to be. Tools such as [comeonin](https://hex.pm/packages/comeonin) or [guardian](https://hex.pm/packages/guardian) are mostly about authentication. Any time you are checking hashes or passwords, you are doing Auth-N.

[Authorization (Auth-Z)](https://en.wikipedia.org/wiki/Authorization) is the process of deciding what a user/entity is allowed to do _after_ they’ve been authenticated.

Authorization ranges from simple (ensuring somebody is logged in), to very rich (make sure the user has specific permissions to see a resource or that one resource is correctly related to the other resources being manipulated).

# Plugs

PolicyWonk provides three main plugs.

* `PolicyWonk.LoadResource` loads resources into the conn's assigns map. 
* `PolicyWonk.Enforce` evaluates a specified policy. It either continues or halts the plug chain depending on the policy result.
* `PolicyWonk.EnforceAction` evaluates a policy for each incoming controller action in Phoenix.

Decisions are made before controller actions are called, isolating authorization logic, encouraging policy re-use, and reducing the odds of messing Auth-Z up as you develop your controllers.

# Behaviours

PolicyWonk defines two behaviours for creating policies and resource loaders.

* `PolicyWonk.Policy` Callbacks for a defining a policy and handling policy failures.
* `PolicyWonk.Loader` Callbacks for defining a resource loader and handing load failures.

You should look at the `PolicyWonk.Policy` documentation.

# Policies outside plugs

In addition to evaluating policies in a plug chain, you will often want to test a policy when rendering ui, acting in a controller, or somewhere else.

`PolicyWonk.Enforce` offers an `authorized?` function just for that purpose. [The documentation ](PolicyWonk.Enforce.html#summary)explains how to use it along with some handy syntatic sugar. 

# Configuration

There are several parameters you can set in the `policy_wonk` configuration block.

    config :policy_wonk, PolicyWonk,
      policies:           MyApp.Policies,
      loaders:            MyApp.Loaders,
      load_async:         true

### Parameters
* `policies` Module containing your centralized `policy` functions. Can also be a list of modules. Default is `nil`.
* `loaders` Module containing your centralized `load_resource` functions. Can also be a list of modules. Default is `nil`.
* `load_async` Boolean value indicating that multiple resources in a single `PolicyWonk.LoadResources` invocation should be loaded asynchronously. Default is `false`. Recommend you set `false` for your tests, `true` elsewhere.

"""
end