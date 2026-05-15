import Config

# Optional: turn on for full-fidelity exploration if you want
# all CLDR locales available at runtime. The default flow works
# without it; this is only needed when you pick a locale that
# wasn't pre-compiled into your build.
config :localize, allow_runtime_locale_download: true
