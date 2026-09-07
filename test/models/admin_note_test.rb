require "test_helper"

class AdminNoteTest < ActiveSupport::TestCase
  test "requires a body" do
    note = AdminNote.new(user: users(:admin))
    assert_not note.valid?
    assert_includes note.errors[:body], "can't be blank"
  end

  test "can be saved without a user" do
    note = AdminNote.new(body: "Anonymous note")
    assert note.valid?
  end

  test "belongs to a user optionally" do
    note = admin_notes(:one)
    assert_equal users(:admin), note.user
  end
end
