require Rails.root.join("db/migrate/20261103120100_load_platform_document_types")

# The platform's document types the data migration loads (spec 08, D-642), which the
# test database, built from the schema, does not have.
module DocumentHelpers
  def load_platform_document_types
    LoadPlatformDocumentTypes.new.up unless PlatformDocumentType.exists?
  end
end

RSpec.configure do |config|
  config.include DocumentHelpers
end
