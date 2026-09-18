require "test_helper"

class UserImportTest < ActiveSupport::TestCase
  test "creates a user per row from the required columns alone" do
    result = import(<<~CSV)
      login_id,password
      newbie@example.com,supersecret
    CSV

    assert_equal 1, result.created_count
    user = User.find_by(login_id: "newbie@example.com")
    assert user.authenticate("supersecret")
    assert_equal "user", user.role
    assert user.active?
  end

  test "falls back to the login id when no name is given" do
    import(<<~CSV)
      login_id,password
      newbie@example.com,supersecret
    CSV

    assert_equal "newbie@example.com", User.find_by(login_id: "newbie@example.com").name
  end

  test "uses the optional name, role and locale columns when present" do
    import(<<~CSV)
      login_id,password,name,role,locale
      boss@example.com,supersecret,Big Boss,admin,ja
    CSV

    user = User.find_by(login_id: "boss@example.com")
    assert_equal "Big Boss", user.name
    assert_equal "admin", user.role
    assert_equal "ja", user.locale
  end

  test "skips a login id that already exists without touching it" do
    existing = users(:member)
    digest_before = existing.password_digest

    result = import(<<~CSV)
      login_id,password
      #{existing.login_id},brandnewpassword
    CSV

    assert_equal 0, result.created_count
    assert_equal 1, result.skipped_count
    assert_equal digest_before, existing.reload.password_digest
    assert_equal :skipped, result.rows.first.status
  end

  test "reports an invalid row by line number and keeps importing the rest" do
    result = import(<<~CSV)
      login_id,password
      bad-row@example.com,hunter7
      good-row@example.com,supersecret
    CSV

    assert_equal 1, result.created_count
    assert_equal 1, result.failed_count
    failed = result.rows.find { |row| row.status == :failed }
    assert_equal 2, failed.line, "the first data row is line 2 of the spreadsheet"
    assert_match(/password/i, failed.message)
    assert User.exists?(login_id: "good-row@example.com")
  end

  test "never echoes the password back in the result rows" do
    result = import(<<~CSV)
      login_id,password
      bad-row@example.com,hunter7
    CSV

    assert_no_match(/hunter7/, result.rows.map { |row| [ row.login_id, row.message ].join(" ") }.join("\n"))
  end

  test "reads a file saved by Excel with a UTF-8 BOM" do
    result = import("﻿login_id,password\nbom@example.com,supersecret\n")

    assert_equal 1, result.created_count
    assert User.exists?(login_id: "bom@example.com")
  end

  test "is invalid without the required columns" do
    importer = UserImport.new(file: uploaded("name,role\nNobody,user\n"))

    assert_not importer.valid?
    assert importer.errors[:file].any?
  end

  test "is invalid without a file" do
    assert_not UserImport.new(file: nil).valid?
  end

  test "refuses a file with more rows than the limit" do
    rows = Array.new(UserImport::MAX_ROWS + 1) { |i| "user#{i}@example.com,supersecret" }
    importer = UserImport.new(file: uploaded(([ "login_id,password" ] + rows).join("\n")))

    assert_not importer.valid?
  end

  test "the template CSV is a header row of every supported column" do
    csv = UserImport.template_csv

    assert_equal(
      (UserImport::REQUIRED_HEADERS + UserImport::OPTIONAL_HEADERS).join(","),
      csv.delete_prefix(UserImport::UTF8_BOM).strip
    )
  end

  test "the template CSV leads with a BOM so Excel reads it as UTF-8" do
    assert UserImport.template_csv.start_with?(UserImport::UTF8_BOM)
  end

  test "the template CSV round-trips through the importer as an empty file" do
    importer = UserImport.new(file: uploaded(UserImport.template_csv))

    assert importer.valid?, importer.errors.full_messages.to_sentence
    assert_equal 0, importer.run.rows.size
  end

  private

    def import(csv)
      importer = UserImport.new(file: uploaded(csv))
      assert importer.valid?, importer.errors.full_messages.to_sentence
      importer.run
    end

    def uploaded(csv)
      Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "users.csv")
    end
end
