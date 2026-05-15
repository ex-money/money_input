import Config

# Enable the visualizer by default in dev. Production never opts
# in — see `Money.Input.Visualizer.Standalone` for the rationale.
# This is the only config the visualizer needs to run; the
# default locale (`:en`) and its currency (USD) resolve out of
# the box.
config :ex_money_input, visualizer: true

# Optional: turn on for full-fidelity exploration if you want
# the locale dropdown to be able to load every CLDR locale on
# demand. The default flow works without it; this is only
# needed when you pick a locale that wasn't pre-compiled into
# your build.
config :localize, allow_runtime_locale_download: true
