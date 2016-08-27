use Mix.Config

config :policy_wonk, PolicyWonk,
  policy_modules:     [PolicyWonk.Test.Policies],
  loader:             PolicyWonk.Test.Loader,
  load_async:         false
