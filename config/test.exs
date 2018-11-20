use Mix.Config

config :policy_wonk, PolicyWonk,
  # can be just one module too
  policies: [PolicyWonk.Test.Policies],
  # can be just one module too
  loaders: [PolicyWonk.Test.Loaders],
  load_async: false
