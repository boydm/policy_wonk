policy_wonk
========

A lightweight authorization and resource loading tool for use with any Plug or Phoenix application.

## Setup

Add `policy_wonk` to the deps section of your application's `mix.exs` file

```elixir
defp deps do
  [
    # ...
    {:policy_wonk, "~> 0.1"}
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

You write your own policy and resource loading functions.

## Documentation

You can read [the full documentation here](https://hexdocs.pm/policy_wonk).

