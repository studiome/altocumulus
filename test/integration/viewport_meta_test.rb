require "test_helper"

# iOS Safari shrinks a page whose content is wider than the screen until all of
# it fits, which made the operations calendar's wide surgery ledger unreadably
# small. shrink-to-fit=no keeps the page at its natural size, so the ledger
# scrolls sideways instead; pinch zoom stays available.
class ViewportMetaTest < ActionDispatch::IntegrationTest
  test "the page is not shrunk to fit wide content and can still be zoomed" do
    get operations_calendar_path

    content = css_select("meta[name=viewport]").first["content"].split(",").map(&:strip)
    assert_includes content, "width=device-width"
    assert_includes content, "initial-scale=1"
    assert_includes content, "shrink-to-fit=no"
    assert content.none? { |part| part.start_with?("maximum-scale", "user-scalable") }
  end
end
