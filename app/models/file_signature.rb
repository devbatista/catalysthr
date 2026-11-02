# The real type of an uploaded file, by its first bytes and not by its name or the type
# the browser sent (P-05-30, RN-08-010, D-640). Only the types the system accepts.
module FileSignature
  SIGNATURES = {
    "application/pdf" => "%PDF-".b,
    "image/png" => "\x89PNG\r\n\x1A\n".b,
    "image/jpeg" => "\xFF\xD8\xFF".b
  }.freeze

  module_function

  def content_type(io)
    io.rewind
    head = io.read(8).to_s.b
    SIGNATURES.find { |_type, signature| head.start_with?(signature) }&.first
  ensure
    io.rewind
  end
end
