import Config

# Allow Localize to download CLDR locale data on demand at runtime
# so the visualizer can show every locale in its dropdown without
# pre-compiling all of them into the build.
config :localize, allow_runtime_locale_download: true

# Enable the visualizer by default in dev. Production never opts
# in — see `Money.Input.Visualizer.Standalone` for the rationale.
config :money_input, visualizer: true
