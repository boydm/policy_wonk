policy_wonk
========

[![Build Status](https://travis-ci.org/boydm/policy_wonk.svg?branch=master)](https://travis-ci.org/boydm/policy_wonk)
[![Hex.pm](https://img.shields.io/hexpm/v/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)
[![Hex.pm](https://img.shields.io/hexpm/dw/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)
[![Hex.pm](https://img.shields.io/hexpm/dt/policy_wonk.svg)](https://hex.pm/packages/policy_wonk)

PolicyWonk is a lightweight authorization and resource loading library for any Plug or Phoenix application. [Authorization (Auth-Z)](https://en.wikipedia.org/wiki/Authorization) is the process of deciding what a user/entity is allowed to do _after_ they’ve been authenticated.

## What's coming

I'm working on changes (as time allows) to make Policy Wonk work well in Phoenix 1.3 umbrella applications. This will probably mean a small number of breaking changes, so may be a major version number bump.

Also re-thinking error flow given Phoenix 1.3's cool new controller actions and how they recover from errors. If you use Policy Wonk and have opinions on how you would like to see this work, this is a good time to make suggestions...

## Setup

Add `policy_wonk` to the deps section of your application's `mix.exs` file

```elixir
defp deps do
  [
    # ...
    {:policy_wonk, "~> 0.2"}
    # ...
  ]
end
```

Don't forget to run `mix deps.get`

## Plugs

PolicyWonk provides three main plugs.

* `PolicyWonk.LoadResource` loads resources into the conn's assigns map. 
* `PolicyWonk.Enforce` evaluates a specified policy. It either continues or halts the plug chain depending on the policy result.
* `PolicyWonk.EnforceAction` evaluates a policy for each incoming controller action in Phoenix.

Decisions are made before controller actions are called, isolating authorization logic, encouraging policy re-use, and reducing the odds of messing Auth-Z up as you develop your controllers.

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


## Tutorial

You can read [a full tutorial on setting up and using policy wonk here](https://medium.com/@boydm/policy-wonk-the-tutorial-6d2b6e435c46#.nqg6cv9ra). 

## Documentation

You can read [the full documentation here](https://hexdocs.pm/policy_wonk).

