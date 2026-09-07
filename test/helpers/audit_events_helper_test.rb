require "test_helper"

class AuditEventsHelperTest < ActionView::TestCase
  include AuditEventsHelper

  # A boolean change value is rendered as a localized Yes/No rather than
  # Ruby's true/false, regardless of whether the attribute maps to an actual
  # :boolean column (audit_change_value checks value == true/false before it
  # ever looks at column_type, so this covers both an unknown attribute and a
  # real boolean column the same way).
  test "boolean change values render as Yes/No, localized" do
    event = AuditEvent.new(
      auditable_type: "Patient",
      auditable_id: 1,
      action: "update",
      record_label: "Test Patient",
      change_data: { "some_flag" => [ false, true ] }
    )

    row = audit_change_rows(event).first
    assert_equal "No", row[:before]
    assert_equal "Yes", row[:after]

    I18n.with_locale(:ja) do
      row_ja = audit_change_rows(event).first
      assert_equal "いいえ", row_ja[:before]
      assert_equal "はい", row_ja[:after]
    end
  end

  test "a nil/blank change value renders as a plain dash in either locale" do
    event = AuditEvent.new(
      auditable_type: "Patient",
      auditable_id: 1,
      action: "update",
      record_label: "Test Patient",
      change_data: { "note" => [ nil, "" ] }
    )

    row = audit_change_rows(event).first
    assert_equal "-", row[:before]
    assert_equal "-", row[:after]

    I18n.with_locale(:ja) do
      row_ja = audit_change_rows(event).first
      assert_equal "-", row_ja[:before]
      assert_equal "-", row_ja[:after]
    end
  end
end
