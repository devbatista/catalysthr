# WCAG 2.x contrast ratio between two "#RRGGBB" colors (RN-01-031).
module ColorContrast
  HEX_FORMAT = /\A#[0-9a-fA-F]{6}\z/

  module_function

  def ratio(color, other)
    lighter, darker = [ luminance(color), luminance(other) ].sort.reverse
    (lighter + 0.05) / (darker + 0.05)
  end

  def luminance(color)
    red, green, blue = color.delete_prefix("#").scan(/../).map { |pair| channel(pair.hex / 255.0) }
    0.2126 * red + 0.7152 * green + 0.0722 * blue
  end

  def channel(value)
    value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
  end
end
