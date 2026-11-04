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

  # The sidebar has the secondary color as background (D-597). RN-01-031 checks only the
  # primary's contrast, so the text takes whichever of white and ink reads better.
  SIDEBAR_DARK_TEXT = "#0C1E33"

  def sidebar_text_color(secondary = theme_colors[:secondary])
    readable_text_color(secondary)
  end

  # The text on the primary color, such as a button's: white or ink, whichever reads
  # better, so a light yellow brand gets dark text (spec 16, RN-16-083, CA-16-012).
  def primary_text_color(primary = theme_colors[:primary])
    readable_text_color(primary)
  end

  def readable_text_color(background)
    white = Brand::WHITE
    ColorContrast.ratio(background, white) >= ColorContrast.ratio(background, SIDEBAR_DARK_TEXT) ? white : SIDEBAR_DARK_TEXT
  end

  # On a dark sidebar, the logo for dark backgrounds; on a light one, the other.
  def sidebar_logo_path
    kind = sidebar_text_color == Brand::WHITE ? :logo_dark : :logo_light
    brand_image_path(header_brand, kind)
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
