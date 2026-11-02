# A version of the PDF an acknowledgement item asks to read (spec 06, RN-06-060, P-06-17,
# D-640), at any level. Each new file is the next version; the older ones stay, so an
# acceptance keeps the version it read. The file is only served once the virus scan says
# it is clean (P-05-30).
module ProcessTemplateMaterialDefinition
  extend ActiveSupport::Concern

  CONTENT_TYPE = "application/pdf".freeze
  MAX_SIZE = 10.megabytes

  # By its content, whatever the file's name or the type the browser sent.
  def self.pdf?(io)
    FileSignature.content_type(io) == CONTENT_TYPE
  end

  included do
    self.table_name = "process_template_materials"

    audited

    belongs_to :uploaded_by, class_name: "User"
    has_one_attached :file

    validates :version, numericality: { only_integer: true, greater_than: 0 }
  end

  # The scan's state; a file without one yet is still scanning.
  def scan_status
    file.blob&.file_scan&.status || "scanning"
  end

  def clean?
    scan_status == "clean"
  end

  def infected?
    scan_status == "infected"
  end
end
