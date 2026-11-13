require "test_helper"

# iOS Safari zooms a page out when its content is wider than the screen. The
# operations calendar's ledger is, and its navbar is fixed at the unzoomed
# viewport width, so the zoomed-out page showed a navbar narrower than the
# screen. minimum-scale=1 keeps the page at its natural size (it scrolls
# sideways instead); zooming in stays possible.
class ViewportMetaTest < ActionDispatch::IntegrationTest
  test "the viewport never zooms out below the natural size but can still zoom in" do
    get operations_calendar_path

    content = css_select("meta[name=viewport]").first["content"].split(",").map(&:strip)
    assert_includes content, "width=device-width"
    assert_includes content, "initial-scale=1"
    assert_includes content, "minimum-scale=1"
    assert content.none? { |part| part.start_with?("maximum-scale", "user-scalable") }
  end
end
