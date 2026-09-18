require "test_helper"

class Admin::UserImportsControllerTest < ActionDispatch::IntegrationTest
  test "admin can open the CSV import form" do
    get new_admin_user_import_url

    assert_response :success
    assert_select "input[type=file][name='user_import[file]']"
  end

  test "member cannot open the CSV import form" do
    sign_out
    sign_in_as(users(:member))

    get new_admin_user_import_url
    assert_redirected_to root_url
  end

  test "admin can import users from a CSV" do
    assert_difference("User.count", 2) do
      post admin_user_import_url, params: { user_import: { file: csv_file(<<~CSV) } }
        login_id,password,name
        first@example.com,supersecret,First User
        second@example.com,supersecret,
      CSV
    end

    assert_response :success
    assert_select "body", /First User|first@example.com/
  end

  test "the result lists skipped and failed rows" do
    post admin_user_import_url, params: { user_import: { file: csv_file(<<~CSV) } }
      login_id,password
      #{users(:member).login_id},supersecret
      broken@example.com,hunter7
    CSV

    assert_response :success
    assert_match users(:member).login_id, @response.body
    assert_match "broken@example.com", @response.body
    assert_no_match(/hunter7/, @response.body)
  end

  test "a CSV without the required columns is rejected" do
    assert_no_difference("User.count") do
      post admin_user_import_url, params: { user_import: { file: csv_file("name\nNobody\n") } }
    end

    assert_response :unprocessable_entity
  end

  # An untouched file field still submits, as an empty string.
  test "submitting the form without picking a file is rejected" do
    post admin_user_import_url, params: { user_import: { file: "" } }

    assert_response :unprocessable_entity
  end

  test "member cannot import users" do
    sign_out
    sign_in_as(users(:member))

    assert_no_difference("User.count") do
      post admin_user_import_url, params: { user_import: { file: csv_file("login_id,password\nx@example.com,supersecret\n") } }
    end

    assert_redirected_to root_url
  end

  private

    def csv_file(contents)
      Rack::Test::UploadedFile.new(StringIO.new(contents), "text/csv", original_filename: "users.csv")
    end
end
