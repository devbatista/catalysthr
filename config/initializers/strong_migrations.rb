# Mark existing migrations as safe: the baseline with UUID keys (D-614).
StrongMigrations.start_after = 20261019180000

# Set timeouts for migrations
# If you use PgBouncer in transaction mode, delete these lines and set timeouts on the database user
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Analyze tables after indexes are added
# Outdated statistics can sometimes hurt performance
StrongMigrations.auto_analyze = true

# Set the version of the production database
# so the right checks are run in development
# StrongMigrations.target_version = 18

# Every table has a UUIDv7 primary key and every reference is a UUID (D-614, AGENTS.md,
# section 3). Only solid_cache_entries keeps a numeric id.
StrongMigrations.add_check do |method, args|
  options = args.last.is_a?(Hash) ? args.last : {}
  if method == :create_table && args.first.to_s != "solid_cache_entries" &&
      (options[:id] != :uuid || options[:default].nil?)
    stop! "Every table uses a UUIDv7 primary key (D-614): create_table :#{args.first}, id: :uuid, default: -> { \"uuidv7()\" }"
  end
  if method.in?(%i[add_reference add_belongs_to]) && options[:type] != :uuid
    stop! "Every reference is a UUID (D-614): #{method} :#{args[0]}, :#{args[1]}, type: :uuid"
  end
end

# Remove invalid indexes when rerunning migrations
# StrongMigrations.remove_invalid_indexes = true

# Make some operations safe by default
# See https://github.com/ankane/strong_migrations#safe-by-default
# StrongMigrations.safe_by_default = true
