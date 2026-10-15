# Feature flags stored in Postgres (spec 20, RN-20-030, P-20-11). New features start
# disabled and are turned on per company before everyone (AGENTS.md, section 3).
Rails.application.configure do
  # Raise in development and tests when code checks a feature nobody declared.
  config.flipper.strict = Rails.env.local? && :raise
end
