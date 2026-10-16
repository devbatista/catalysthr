# Absolute links to the platform's hosts (spec 01, RN-01-001): the brands' subdomains
# and the admin area. Used where there is no request to copy the host from, such as
# e-mails, and to cross from one host to the other.
module PlatformUrl
  module_function

  def build(host, path = "/", **params)
    config = Rails.configuration.x
    port = config.public_port ? ":#{config.public_port}" : ""
    url = "#{config.panel_protocol}://#{host}#{port}#{path}"
    params.any? ? "#{url}?#{params.to_query}" : url
  end

  def admin(path = "/", **params)
    build(Rails.configuration.x.admin_host, path, **params)
  end
end
