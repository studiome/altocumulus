require "test_helper"

class WeeklySurgerySchedulePdfTest < ActiveSupport::TestCase
  def render_text(start_date, locale: :en)
    I18n.with_locale(locale) do
      reader = PDF::Reader.new(StringIO.new(WeeklySurgerySchedulePdf.new(start_date).render))
      reader.pages.map(&:text).join("\n")
    end
  end

  test "renders a landscape A4 PDF" do
    reader = PDF::Reader.new(StringIO.new(WeeklySurgerySchedulePdf.new(Date.new(2026, 3, 1)).render))

    width, height = reader.pages.first.attributes[:MediaBox].values_at(2, 3)
    assert_operator width, :>, height
    assert_in_delta 842, width, 1
    assert_in_delta 595, height, 1
  end

  test "covers exactly seven days from the given start date, not the Monday of that week" do
    # 2026-03-03 is a Tuesday: the week runs Tue 3/3 through Mon 3/9, so the
    # Monday 3/2 surgery must be left out.
    text = render_text(Date.new(2026, 3, 3))

    assert_match(/2026-03-03/, text)
    assert_match(/2026-03-09/, text)
    assert_no_match(/2026-03-02/, text)
    assert_no_match(/2026-03-10/, text)
  end

  test "lists each surgery's patient, procedure and time inside the week" do
    text = render_text(Date.new(2026, 3, 1))

    assert_includes text, "Jane Smith"
    assert_includes text, "H001"
    assert_includes text, "09:00"
    assert_includes text, surgeries(:three).display_procedure_name
  end

  test "shows the operator and assistant under an Operator column" do
    surgeries(:three).update!(operator_name: "Dr. Operator", assistant_name: "Dr. Assistant")

    text = render_text(Date.new(2026, 3, 1))

    assert_includes text, "Operator"
    assert_includes text, "Dr. Operator"
    assert_includes text, "Dr. Assistant"
  end

  test "shows the surgery duration in hours like the surgery list, not minutes" do
    text = render_text(Date.new(2026, 3, 1)) # surgeries(:one) runs 1.5 hours

    assert_includes text, "1.5 h"
    assert_no_match(/\d min\b/, text)
  end

  test "shows the surgery duration in hours in Japanese" do
    assert_includes render_text(Date.new(2026, 3, 1), locale: :ja), "1.5時間"
  end

  test "leaves out surgeries dated outside the week" do
    outside = surgeries(:one).dup
    outside.surgery_date = Date.new(2026, 3, 20)
    outside.surgery_procedure_selections = surgeries(:one).surgery_procedure_selections.map(&:dup)
    outside.save!

    text = render_text(Date.new(2026, 3, 1))

    assert_not_includes text, "2026-03-20"
  end

  test "shows a placeholder for a day with no surgeries" do
    text = render_text(Date.new(2030, 1, 7))

    assert_match(/No surgeries scheduled/, text)
  end

  test "renders Japanese text without raising (embedded font has the glyphs)" do
    text = render_text(Date.new(2026, 3, 1), locale: :ja)

    assert_match(/週間手術予定表/, text)
  end

  test "stamps the print time on the page" do
    travel_to Time.zone.local(2026, 3, 4, 10, 30) do
      assert_match(/Printed/, render_text(Date.new(2026, 3, 1)))
    end
  end
end
