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

  def header_brand_name
    (replacing_brand || Current.brand).commercial_name
  end
end
