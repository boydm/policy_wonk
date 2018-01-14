policy_wonk
========

[![Build Status](https://travis-ci.org/boydm/policy_wonk.svg?branch=master)](https://travis-ci.org/boydm/policy_wonk)
[![Hex.pm](https://img.shields.io/hexpm/v/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)
[![Hex.pm](https://img.shields.io/hexpm/dw/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)
[![Hex.pm](https://img.shields.io/hexpm/dt/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)

PolicyWonk is a lightweight authorization and resource loading library for any Plug or Phoenix application.

Note: I am in the process of building version 1.0. The code and tests look good and I am updating the documentation
now. Expect errors if you read the docs on this branch for now.

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
    {:policy_wonk, "~> 1.0"}
    # ...
  ]
end
```

Don't forget to run `mix deps.get`

## Examples

Load and enforce the current user in a router:

      pipeline :browser_session do
        plug MyAppWeb.Loaders, :current_user
        plug MyAppWeb.Policies, :current_user
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

## Loaders

Loaders are similar to policies in that you define functions that can be used in the plug chain.
Instead of making a yes/now enforcement descision, a loader will load a resource and insert it
into the conn's `assigns` map.


      defmodule MyAppWeb.Loaders do
        use PolicyWonk.Loader         # set up support for loaders
        use PolicyWonk.LoadResource   # turn this module into an load resource plug

        def load_resource( _conn, :user, %{"id" => user_id} ) do
          case MyApp.Account.get_user(user_id) do
            nil ->  {:error, :user}
            %MyApp.Account.User{} = user -> {:ok, :user, user}
          end
        end

        def load_error(conn, _resource_id) do
          MyAppWeb.ErrorHandlers.resource_not_found( conn )
        end
      end

See the the `PolicyWonk.Loader` documentation for details.


## Documentation

You can read [the full documentation here](https://hexdocs.pm/policy_wonk/1.0.0-rc.0).

