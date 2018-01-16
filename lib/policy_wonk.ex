defmodule PolicyWonk do
  @moduledoc """

  A lightweight authorization and resource loading tool for use with any Plug or Phoenix application.

  ## About version 1.0

  Policy Wonk is almost completely re-written for version 1.0. After living with it for well
  over a year, I realized there were a set of issues that warranted re-opening the underlying
  architecture.

  * It wasn't compatible with Phoenix 1.3 umbrella apps. Or rather, you couldn't have seperate
  policies for different apps in an umbrella.
  * It had a whole mess of complexity that simply wasn't needed. I never used
  most of the "shortcut" options since the more explicit versions (with slightly more
  typing) were always clearer.
  * Returning errors from Policies was too vague. I want to know errors are being processed!
  * The config file data isn't necessary in a more explicit model.
  * Naming was inconsistent between policies and resources.

  Version 1.0 takes these observations (and more), fixes them, and simplifies the configuration
  dramatically. It has less code and is overall simpler and faster.

  Please see the section [Upgrading to version 1.0](#module-using-policies-and-loaders)
  below for instructions on how to migrate
  existing policies to version 1.0. There is a small amount of work to do, but it is worth it.

  ## Authentication vs. Authorization

  [Authentication (Auth-N)](https://en.wikipedia.org/wiki/Authentication) is the process of proving that a user or other entity is who/what it claims to be. Tools such as [comeonin](https://hex.pm/packages/comeonin) or [guardian](https://hex.pm/packages/guardian) are mostly about authentication. Any time you are checking hashes or passwords, you are doing Auth-N.

  [Authorization (Auth-Z)](https://en.wikipedia.org/wiki/Authorization) is the process of deciding what a user/entity is allowed to do _after_ they’ve been authenticated.

  Authorization ranges from simple (ensuring somebody is logged in), to very rich (making sure the user has specific permissions to see a resource or that one resource is correctly related to the other resources being manipulated).


  ## Examples

  Load and enforce a current user in a router:

        pipeline :browser_session do
          plug MyAppWeb.Resources,  :current_user
          plug MyAppWeb.Policies,   :current_user
        end
        
        pipeline :admin do
          plug MyAppWeb.Policies, {:admin_permission, "dashboard"}
        end

  In a controller:

        plug MyAppWeb.Policies, {:admin_permission, "dashboard"}



  # Policies

  With PolicyWonk, you create policies and loaders for your application. They can be used
  as plugs in your router or controller or called for yes/no descisions in a template or controller.

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

  # Loaders

  Loaders are similar to policies in that you define functions that can be used in the plug chain.
  Instead of making a yes/no enforcement descision, a loader will load a resource and insert it
  into the conn's `assigns` map.


        defmodule MyAppWeb.Resources do
          use PolicyWonk.Resource       # set up support for loaders
          use PolicyWonk.Load           # turn this module into an load resource plug

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

  See the the `PolicyWonk.Resource` documentation for details.


  # Behaviours

  PolicyWonk defines two behaviours for creating policies and resource loaders.

  * `PolicyWonk.Policy` Callbacks for defining a policy and handling policy failures.
  * `PolicyWonk.Resource` Callbacks for defining a resource loader and handing load failures.

  # Policies outside plugs

  In addition to evaluating policies in a plug chain, you will often want to test a policy
  when rendering ui, processing an action in a controller, or somewhere else.

  The `use PolicyWonk.Policy` call in your policy module adds the `enforce!/2` and `authorized?/2`
  functions, which you can use in templates or controllers to decide what UI to show or to raise
  an error under certain conditions.

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



  ## Configuration

  You no longer need to set up anything in your config files.

  Just create the appropriate policy or loader modules and use them directly.

  # Upgrading to version 1.0

  ## Module Names

  The two resource loading modules have been renamed to make them more consistent with policies.

  PolicyWonk.LoadResource ->    PolicyWonk.Load
  PolicyWonk.Loader ->          PolicyWonk.Resource
  

  ## Using policies and Loaders

  You no longer directly call `PolicyWonk.Policy` and `PolicyWonk.Load` as plugs
  from your router.

  After using them in your policy modules, call ***your*** module in the router. This lets you be
  explict about which policy modules are used where without anything in config.exs.

  You can have different policy modules for different apps in an umbrella project, or simply build
  up a library policy modules that you can re-use as appropriate.

        # Old. Don't do this
        # pipeline :browser_session do
        #   plug PolicyWonk.Load, :current_user
        #   plug PolicyWonk.Enforce, :current_user
        # end

        # New. Do this
        pipeline :browser_session do
          plug MyAppWeb.Resources, :current_user
          plug MyAppWeb.Policies, :current_user
        end


  ## Policies

  Policies now require you to be more specific about when the policy fails. Previously, :ok was
  success and anything else was a failure. This lead to code that wasn't obvious about what
  the failure cases were. Now the only accepted return values are :ok and {:error, message}.

  The `message` part of `{:error, message}` can be any term you want and will be passed, unchanged, into
  your `policy_error` function.

        # Old. Don't do this
        # def policy( assigns, :current_user ) do
        #   case assigns[:current_user] do
        #     %MyApp.Account.User{} ->
        #       :ok
        #     _ ->
        #       :current_user
        #   end
        # end

        # New. Do this
        def policy( assigns, :current_user ) do
          case assigns[:current_user] do
            %MyApp.Account.User{} ->
              :ok
            _ ->
              {:error, :current_user}
          end
        end


  ## Loaders

  Loaders also now require you to be more specific about when loading a resource fails. Previously,
  {:ok, key, resource} was success and anything else was a failure. This lead to code that wasn't
  obvious about what the failure cases were. Now the only accepted return values are {:ok, key, resource}
  and {:error, message}.

  The `message` part of `{:error, message}` can be any term you want and will be passed, unchanged, into
  your `load_error` function.

        # Old. Don't do this
        # case Repo.get(User, user_id) do
        #   nil ->  :user
        #   user -> {:ok, :user, nil}
        # end

        # New. Do this
        case MyApp.Account.get_user(user_id) do
          nil ->  {:error, :user}
          user -> {:ok, :user, user}
        end


  ## Local Policies and Loaders in a Controller

  Previously, you could simply define a policy in a controller and it would override whatever was
  in your policy module. You can still have a policy or loader specific to a controller, but you
  need to call it as a plug in a more explicit fashion. This is more functional in nature.

  To use a policy that is local to a controller, call `use PolicyWonk.Policy` at the top of your
  controller. This adds a small set of functions to your controller including `enforce/2`, which
  allows you to call local policies as a plug.


        # Old. Don't do this
        # defmodule MyAppWeb.Controller.AdminController do
        #   use MyAppWeb, :controller
        # 
        #   plug PolicyWonk.Enforce :user
        #
        #   policy(conn, :user) do
        #     ...
        #   end
        # end

        # New. Do this
        defmodule MyAppWeb.Controller.AdminController do
          use MyAppWeb, :controller
          use PolicyWonk.Policy

          plug :enforce, :user

          policy(conn, :user) do
            ...
          end
        end

  Note that you do not need to call `use PolicyWonk.Enforce` to use a local policy in a controller.
  `PolicyWonk.Enforce` is only used to turn a module into a plug that can be called from a router.
  """
end
