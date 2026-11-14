# Be sure to restart your server when you modify this file.

# Content security policy for every HTML response. Scripts are the app's own
# importmap modules plus the importmap/module tags Rails renders inline, which
# carry a nonce. Styles allow 'unsafe-inline' because views set inline style
# attributes (dashboard bars, theme swatches, frozen ledger columns), which a
# nonce cannot cover; there is no inline <script> or event-handler attribute
# anywhere, so script-src stays strict.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self
    policy.style_src       :self, :unsafe_inline
    policy.img_src         :self, :data
    policy.font_src        :self, :data
    policy.object_src      :none
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
    # The live update socket is same-host only. 'self' alone covers ws(s) in
    # current browsers but not in Safari, so the origin is named explicitly.
    # The lambdas run in the controller, or in the request itself when the
    # policy is built outside a controller (routing errors).
    same_host = ->(scheme) { -> { "#{scheme}://#{(respond_to?(:request) ? request : self).host_with_port}" } }
    policy.connect_src     :self, same_host.("ws"), same_host.("wss")
  end

  # One nonce per session (not per request): Turbo compares the tracked
  # importmap tag of the next page with the current one, and a nonce that
  # changed on every request would force a full reload on every visit.
  config.content_security_policy_nonce_generator = ->(request) do
    request.session[:csp_nonce] ||= SecureRandom.base64(16)
  end
  config.content_security_policy_nonce_directives = %w[ script-src ]
end
