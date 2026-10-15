# Random tokens that travel in links and cookies. Only their SHA-256 digest is stored,
# so a copy of the database does not open anything.
module SecureToken
  module_function

  def generate
    SecureRandom.urlsafe_base64(32)
  end

  def digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end
end
