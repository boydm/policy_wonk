use Mix.Config

config :policy_wonk, PolicyWonk,
  policy_modules:     [PolicyWonk.Test.Policies],     # can be just one module too
  loader:             [PolicyWonk.Test.Loaders],      # can be just one module too
  load_async:         false
