module BrandingHelper
  # The brand shown on the panel's pages. With a partner's company chosen in replace
  # mode, the company's brand takes the place of the partner's, with the partner's and
  # then CatalystHR's in its empty fields (RN-01-034, RN-01-035). The sign-in pages come
  # before the company, so they always show the subdomain's brand.
  def replacing_brand
    company = Current.company
    company.brand if company&.brand_replace? && company.brand
  end

  def theme_colors
    replacing_brand&.colors(fallback: Current.brand) || Current.brand.colors
  end

  def header_brand
    replacing_brand || Current.brand
  end

  def header_brand_name
    header_brand.commercial_name
  end

  # The address of one of the brand's images, or nil without it. The version changes
  # with the file, so a new logo shows at once despite the cache.
  def brand_image_path(brand, kind)
    attachment = brand&.public_send(kind)
    return unless attachment&.attached?

    if brand == Current.brand
      brand_asset_path(kind: kind, v: attachment.blob_id)
    elsif Current.company && brand == Current.company.brand
      company_brand_asset_path(kind: kind, v: attachment.blob_id)
    end
  end

  # In alongside mode the company's logo shows next to the partner's (RN-01-034).
  def alongside_company_logo_path
    company = Current.company
    brand_image_path(company.brand, :logo_light) if company&.brand_alongside? && company.brand
  end
end
