module QrCodeHelper
  # QR code as inline SVG, drawn on the server (RN-02-042). The SVG holds only the
  # squares' geometry: the encoded text never appears in it.
  def qr_code_svg(data)
    RQRCode::QRCode.new(data).as_svg(module_size: 4, standalone: true, use_path: true, viewbox: true).html_safe # rubocop:disable Rails/OutputSafety
  end
end
