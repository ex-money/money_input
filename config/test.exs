import Config

# Tests need on-demand CLDR loading too — they exercise locales
# like fa, fr-CH, etc. that aren't pre-compiled.
config :localize, allow_runtime_locale_download: true

# The library never converts currencies, so the exchange rate service
# is not needed (ex_money 6.3 warns when it starts automatically).
config :ex_money, auto_start_exchange_rate_service: false
