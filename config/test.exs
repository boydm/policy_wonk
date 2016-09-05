use Mix.Config

config :policy_wonk, PolicyWonk,
  policies:       [PolicyWonk.Test.Policies],     # can be just one module too
  loaders:        [PolicyWonk.Test.Loaders],      # can be just one module too
  load_async:     false
