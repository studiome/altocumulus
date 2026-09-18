require "application_system_test_case"

class UserImportsTest < ApplicationSystemTestCase
  test "an admin imports users from a CSV and sees what happened to each row" do
    visit admin_users_path

    click_on "Import from CSV"
    attach_file "CSV file", Rails.root.join("test/fixtures/files/users_import.csv")

    assert_difference("User.count", 2) do
      click_on "Import"
      assert_text "Import Result"
    end

    assert_text "2 registered, 1 skipped, 1 failed."

    assert_text "imported-one@example.com"
    assert_text "member@example.com"
    assert_text "broken@example.com"
    assert_no_text "hunter7"

    # The optional columns are applied, and a row with no name falls back to
    # its login id.
    assert_equal "Imported One", User.find_by(login_id: "imported-one@example.com").name
    assert_equal "imported-two@example.com", User.find_by(login_id: "imported-two@example.com").name
    assert_predicate User.find_by(login_id: "imported-two@example.com"), :admin?

    click_on "Back to Users"
    assert_text "Imported One"
  end
end
