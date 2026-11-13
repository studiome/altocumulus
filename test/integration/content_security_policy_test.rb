require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "pages carry a content security policy" do
    get patients_url
    csp = response.headers["Content-Security-Policy"]

    assert csp.present?
    assert_match(/default-src 'self'/, csp)
    assert_match(/script-src 'self' 'nonce-[^']+'/, csp)
    assert_match(/object-src 'none'/, csp)
    assert_match(/base-uri 'self'/, csp)
    assert_match(/form-action 'self'/, csp)
    assert_match(/frame-ancestors 'none'/, csp)
    assert_match(/img-src 'self' data:/, csp)
    assert_match(/font-src 'self' data:/, csp)
    assert_no_match(/script-src[^;]*unsafe-inline/, csp)
  end

  test "every script tag in the layout carries the nonce of the policy" do
    get patients_url
    nonce = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]

    assert nonce.present?
    scripts = css_select("script")
    assert scripts.any?
    scripts.each { |script| assert_equal nonce, script["nonce"], script.to_s[0, 80] }
    assert_select "meta[name=csp-nonce][content=?]", nonce
  end

  test "the nonce stays the same within a session so Turbo does not reload tracked scripts" do
    get patients_url
    first = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    get hospitalizations_url
    assert_equal first, response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
  end

  test "the sign-in page carries the policy too" do
    sign_out
    get login_url
    assert_match(/script-src 'self' 'nonce-/, response.headers["Content-Security-Policy"])
  end

  test "the schedule PDF is served without a policy header" do
    get surgery_schedule_pdf_url
    assert_response :success
    assert_nil response.headers["Content-Security-Policy"]
  end
end
