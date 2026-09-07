require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  test "requires a title" do
    announcement = Announcement.new(body: "Body only")
    assert_not announcement.valid?
    assert_includes announcement.errors[:title], "can't be blank"
  end

  test "requires a body" do
    announcement = Announcement.new(title: "Title only")
    assert_not announcement.valid?
    assert_includes announcement.errors[:body], "can't be blank"
  end

  test "defaults to published" do
    assert Announcement.new.published
  end

  test "published scope only returns published announcements" do
    assert_includes Announcement.published, announcements(:published_one)
    assert_not_includes Announcement.published, announcements(:draft_one)
  end
end
