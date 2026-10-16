module Brands
  # A partner's client company's own brand and how it shows after sign-in (RN-01-034,
  # RN-01-035, D-163, D-165): the brand is created on the first save. Only the name and
  # the colors (and the logo, with the images) apply to it: the sign-in, the subdomain,
  # the support and the e-mail domain stay the partner's.
  class UpdateCompanyBrand
    ATTRIBUTES = %i[commercial_name primary_color secondary_color accent_color].freeze

    def self.call(**)
      new(**).call
    end

    def initialize(company:, attributes:, display_mode:)
      @company = company
      @attributes = attributes.to_h.symbolize_keys.slice(*ATTRIBUTES)
      @display_mode = display_mode
    end

    # Returns the brand; it holds the errors when it is invalid.
    def call
      brand = @company.brand || @company.build_brand
      brand.assign_attributes(@attributes.transform_values(&:presence))
      Brand.transaction do
        brand.save!
        @company.update!(brand_display_mode: @display_mode) if @display_mode.present?
      end
      brand
    rescue ActiveRecord::RecordInvalid => error
      brand.errors.merge!(error.record.errors) unless error.record == brand
      brand
    end
  end
end
