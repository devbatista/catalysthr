# Resolves every request by its host (spec 01, RN-01-001):
# - the admin host opens the CatalystHR admin area (D-156);
# - <slug>.<panel domain> opens that brand's panel;
# - a slug inside its 90-day redirect answers 301 to the same path on the new slug (D-157);
# - anything else gets a neutral 404 page, without a brand.
# The health check answers on any host, so the uptime monitor never depends on a
# brand (D-573).
class HostResolver
  AREA = "catalysthr.area"
  BRAND_ID = "catalysthr.brand_id"
  HEALTH_CHECK_PATH = "/up"

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    return @app.call(env) if request.path == HEALTH_CHECK_PATH

    host = request.host.to_s.downcase
    return admin(env) if host == config.admin_host

    slug = slug_for(host)
    result = slug && Brands::HostLookup.call(slug)

    if result&.active?
      env[AREA] = :panel
      env[BRAND_ID] = result.brand_id
      @app.call(env)
    elsif result&.redirecting?
      redirect(request, result)
    else
      not_found
    end
  end

  private

  def admin(env)
    env[AREA] = :admin
    @app.call(env)
  end

  # Only one label before the panel domain: "aurora.painel..." but not "a.b.painel...".
  def slug_for(host)
    suffix = ".#{config.panel_domain}"
    return unless host.end_with?(suffix)

    slug = host.delete_suffix(suffix)
    slug unless slug.include?(".")
  end

  # Browsers cache a 301 indefinitely unless told otherwise. The cache ends with the
  # redirect period, so a released slug can serve a new brand later.
  def redirect(request, result)
    location = "#{request.scheme}://#{result.target_slug}.#{config.panel_domain}#{request.port_string}#{request.fullpath}"
    max_age = [ (result.redirect_until - Time.current).to_i, 0 ].max
    [ 301, { "location" => location, "cache-control" => "public, max-age=#{max_age}" }, [] ]
  end

  def not_found
    [ 404, { "content-type" => "text/html; charset=utf-8", "cache-control" => "no-store" }, [ not_found_page ] ]
  end

  def not_found_page
    @not_found_page ||= Rails.public_path.join("404.html").read
  end

  def config
    Rails.configuration.x
  end
end
