import Config

# Tests need on-demand CLDR loading too — they exercise locales
# like fa, fr-CH, etc. that aren't pre-compiled.
config :localize, allow_runtime_locale_download: true
