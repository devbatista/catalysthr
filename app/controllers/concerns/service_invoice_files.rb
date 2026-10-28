# The NFS-e's PDF and XML (RN-19-107, D-564), served by the application after the invoice's
# own check, like every file (RN-01-014): the bucket stays private and its addresses never
# reach the browser.
module ServiceInvoiceFiles
  private

  def send_service_invoice_file(invoice)
    raise ActiveRecord::RecordNotFound unless FeatureFlags.enabled?(FeatureFlags::NFSE)

    attachment = invoice.service_invoice&.public_send(params[:kind] == "xml" ? :xml : :pdf)
    raise ActiveRecord::RecordNotFound unless attachment&.attached?

    response.headers["Cache-Control"] = "private, no-store"
    send_data attachment.download, type: attachment.content_type, disposition: :attachment, filename: attachment.filename.to_s
  end
end
