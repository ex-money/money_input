import Config

# Optional: turn on for full-fidelity exploration if you want
# all CLDR locales available at runtime. The default flow works
# without it; this is only needed when you pick a locale that
# wasn't pre-compiled into your build.
config :localize, allow_runtime_locale_download: true

# The library never converts currencies, so the exchange rate service
# is not needed (ex_money 6.3 warns when it starts automatically).
config :ex_money, auto_start_exchange_rate_service: false
