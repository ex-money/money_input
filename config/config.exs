import Config

# Per-environment overrides live in the file named for that env.
# Default config is intentionally empty — production hosts should
# opt in to behaviour like runtime locale download.
import_config "#{config_env()}.exs"
