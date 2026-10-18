# Content security policy and security headers (spec 05, P-05-29, D-606).
# Scripts and styles come only from the app's own files or carry the request's nonce:
# the importmap tags and the brand's colors in the panel layout. Style attributes are
# blocked, so views never use them. Images also come from the OpenStreetMap tiles of the
# unit's map (D-216) and from data URIs (the form icons of the CSS). There is no report
# URI: a report carries the page's URL, which may hold an invitation token.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.object_src :none
    policy.frame_ancestors :none
    policy.script_src :self
    policy.style_src :self
    policy.img_src :self, :data, "https://tile.openstreetmap.org"
    policy.font_src :self
    policy.connect_src :self
  end

  # A new nonce on every request; no page is served from an HTTP cache.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Pages are never shown in a frame, also in browsers without frame-ancestors.
  config.action_dispatch.default_headers["X-Frame-Options"] = "DENY"
end
