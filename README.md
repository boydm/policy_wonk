policy_wonk
========

[![Build Status](https://travis-ci.org/boydm/policy_wonk.svg?branch=master)](https://travis-ci.org/boydm/policy_wonk)
[![Hex.pm](https://img.shields.io/hexpm/v/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)
[![Inline docs](http://inch-ci.org/github/boydm/phoenix_integration.svg?branch=master)](http://inch-ci.org/github/boydm/phoenix_integration)
[![Hex.pm](https://img.shields.io/hexpm/dw/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)
[![Hex.pm](https://img.shields.io/hexpm/dt/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)

PolicyWonk is a lightweight authorization and resource loading library for any Plug or Phoenix application.

## Note on v1.0.0-rc.0

I just released version 1.0.0-rc.0 to hex. The code and tests look good and the docs have
been updated, although probably need proofreading. This is where it is going, so please try it
out and let me know if you see have any issues with it. I'll probably let it sit a few weeks
before declaring it done.

Policy Wonk is almost completely re-written for version 1.0. After living with it for well
over a year, I realized there were a set of issues that warranted re-opening the underlying
architecture.

* It wasn't compatible with Phoenix 1.3 umbrella apps. Or rather, you couldn't have separate
policies for different apps in an umbrella.
* It had a whole mess of complexity that simply wasn't needed. I never used
most of the "shortcut" options since the more explicit versions (with slightly more
typing) were always clearer.
* Returning errors from Policies was too vague. I want to know errors are being processed!
* The config file data isn't necessary in a more explicit model.
* Naming was inconsistent between policies and resources.

Version 1.0 takes these observations (and more), fixes them, and simplifies the configuration
dramatically. It has less code and is overall simpler and faster.

There is a little work to upgrade from a older versions, but the overall shape of your code
will stay the same, so the work is small and well worth it.

You can read [the full documentation here](https://hexdocs.pm/policy_wonk/1.0.0-rc.0).

## Authentication vs. Authorization

[Authentication (Auth-N)](https://en.wikipedia.org/wiki/Authentication) is the process of proving that a user or other entity is who/what it claims to be. Tools such as [comeonin](https://hex.pm/packages/comeonin) or [guardian](https://hex.pm/packages/guardian) are mostly about authentication. Any time you are checking hashes or passwords, you are doing Auth-N.

[Authorization (Auth-Z)](https://en.wikipedia.org/wiki/Authorization) is the process of deciding what a user/entity is allowed to do _after_ they’ve been authenticated.

Authorization ranges from simple (ensuring somebody is logged in), to very rich (make sure the user has specific permissions to see a resource or that one resource is correctly related to the other resources being manipulated).


## Setup

Add `policy_wonk` to the deps section of your application's `mix.exs` file

```elixir
defp deps do
  [
    # ...
    {:policy_wonk, "~> 1.0.0-rc.0"}
    # ...
  ]
end
```

Don't forget to run `mix deps.get`

## Examples

Load and enforce the current user in a router:

      pipeline :browser_session do
        plug MyAppWeb.Resources,  :current_user
        plug MyAppWeb.Policies,   :current_user
      end
      
      pipeline :admin do
        plug MyAppWeb.Policies, {:admin_permission, "dashboard"}
      end

In a controller:

      plug MyAppWeb.Policies, {:admin_permission, "dashboard"}


## Policies

With PolicyWonk, you create policies and loaders for your application. They can be used
as plugs in your router or controller or called for yes/now descisions in a template or controller.

This lets you enforce things like "a user is signed in" or "the admin has this permission" in the
router. Or you could use a policy to determine if you should render a set of UI.  

If a policy fails, it halts your plug chain and lets you decide what to do with the error.

Example policy:

      defmodule MyAppWeb.Policies do
        use PolicyWonk.Policy         # set up support for policies
        use PolicyWonk.Enforce        # turn this module into an enforcement plug

        def policy( assigns, :current_user ) do
          case assigns[:current_user] do
            %MyApp.Account.User{} ->
              :ok
            _ ->
              {:error, :current_user}
          end
        end

        def policy_error(conn, :current_user) do
          MyAppWeb.ErrorHandlers.unauthenticated(conn, "Must be logged in")
        end
      end

See the the `PolicyWonk.Policy` documentation for details.

## Policies outside plugs

In addition to evaluating policies in a plug chain, you will often want to test a policy
when rendering ui, processing an action in a controller, or somewhere else.

The `use PolicyWonk.Policy` call in your policy module adds the `enforce!/2` and `authorized?/2`
functions, which you can use in templates or controllers to decide what UI to show or to raise
an error under certain condisions.

In a template:

      <%= if MyAppWeb.Policies.authorized?(@conn, {:admin_permission, "dashbaord"}) do %>
        <%= link "Admin Dashboard", to: admin_dashboard_path(@conn, :index) %>
      <% end %>

In an action in a controller:

      def settings(conn, params) do
        ...
        # raise an error if the current user is not the user specified in the url.
        MyAppWeb.Policies.enforce!(conn, :user_is_self)
        ...
      end

## Resources

Resources are similar to policies in that you define functions that can be used in the plug chain.
Instead of making a yes/now enforcement descision, a `resource` will load a resource and insert it
into the conn's `assigns` map.


      defmodule MyAppWeb.Loaders do
        use PolicyWonk.Resource       # set up support for resources
        use PolicyWonk.Load           # turn this module into an load resource plug

        def resource( _conn, :user, %{"id" => user_id} ) do
          case MyApp.Account.get_user(user_id) do
            nil ->  {:error, :user}
            %MyApp.Account.User{} = user -> {:ok, :user, user}
          end
        end

        def resource_error(conn, _resource_id) do
          MyAppWeb.ErrorHandlers.resource_not_found( conn )
        end
      end

See the the `PolicyWonk.Resource` documentation for details.


## Documentation

You can read [the full documentation here](https://hexdocs.pm/policy_wonk/1.0.0-rc.0).

