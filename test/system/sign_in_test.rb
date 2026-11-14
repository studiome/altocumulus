require "application_system_test_case"

# Keyboard movement on the sign-in form. The IME case (Enter that confirms a
# conversion must not move focus) cannot be driven by Selenium; it is covered
# by the small isComposing / keyCode 229 guard in sign_in_form_controller.js.
class SignInTest < ApplicationSystemTestCase
  setup do
    # The base class signed in as admin; start from a signed-out browser.
    Capybara.reset_sessions!
    visit login_path
    switch_to_english
  end

  %w[email username].each do |mode|
    label = mode == "email" ? "Email" : "Username"

    test "Enter in the #{mode} field with an empty password moves to the password field" do
      with_account_identifier(mode) do
        visit login_path
        failures = AccessLog.where(event: "login_failed").count
        fill_in label, with: users(:admin).login_id
        find_field(label).send_keys(:enter)

        assert_equal "password", evaluate_script("document.activeElement.type")
        assert_current_path login_path
        assert_no_text "Invalid"
        assert_equal failures, AccessLog.where(event: "login_failed").count
      end
    end

    test "Tab from the #{mode} field focuses the password field with the password filled" do
      with_account_identifier(mode) do
        visit login_path
        fill_in "Password", with: "secret"
        find_field(label).send_keys(:tab)
        assert_equal "password", evaluate_script("document.activeElement.type")
      end
    end

    test "Shift+Tab from the password field returns to the #{mode} field (#{mode})" do
      with_account_identifier(mode) do
        visit login_path
        find_field("Password").send_keys([ :shift, :tab ])
        assert_equal "login_id", evaluate_script("document.activeElement.id.replace('session_', '')")
      end
    end

    test "Enter in the password field signs in (#{mode})" do
      with_account_identifier(mode) do
        visit login_path
        fill_in label, with: users(:admin).login_id
        fill_in "Password", with: SignInHelper::DEFAULT_PASSWORD
        find_field("Password").send_keys(:enter)
        assert_selector "form[action='#{logout_path}']", visible: :all, wait: 10
      end
    end

    test "Tab from the #{mode} field focuses the password field" do
      with_account_identifier(mode) do
        visit login_path
        find_field(label).send_keys(:tab)
        assert_equal "password", evaluate_script("document.activeElement.type")
      end
    end

    test "Enter in the #{mode} field with the password filled signs in" do
      with_account_identifier(mode) do
        visit login_path
        fill_in "Password", with: SignInHelper::DEFAULT_PASSWORD
        fill_in label, with: users(:admin).login_id
        find_field(label).send_keys(:enter)
        assert_selector "form[action='#{logout_path}']", visible: :all, wait: 10
      end
    end
  end
end
