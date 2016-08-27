policy_wonk
========

# UNDER DEVELOPMENT
## not yet ready for prime time. Will be soon.

## Summary

PolicyWonk is a lightweight authorization tool for use with any Plug or Phoenix application. Tools such as comeonin or Guardian are about Authentication. PolicyWonk is about deciding what a user can do after they’ve been authenticated.

The core philosophy is that policies (which define what a connection can or cannot do) and resource loaders (what policies decide about) should be readable, understandable and kept in places that make sense.

## Configuration

### Step 1
Add PolicyWonk to the deps section of your application's `mix.exs` file

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

### Step 2
Start using it!

## Overview

A policy that is shared across many controllers should be either in a global policies module or in the router. A policy that is specific to one controller, should be defined in that controller.

After much thought, PolicyWonk is Conn centric. In other words, policies are about what the resources loaded into a conn can do. It is not about putting policy logic in your models. Experience says that gets messy and should be avoided.

For example, a user is authenticated by comonin or Guardian, and is accessed through conn.assigns.current_user. A policy can be defined to examine that current_user and decide if they are allowed to do something.

For a policy to make a good descision, various resource may need to be loaded into assigns before the policy is called. Since a goal is to make these decisions before your controller action is called, then they must be loaded via a plug. PolicyWonk provides the LoadResource plug just to do this. It can be run syncronously (test and debugging) or asynchronously for speed.