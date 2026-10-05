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

  test "shows a holiday's name and note on the day heading" do
    Holiday.create!(date: Date.new(2026, 3, 4), name: "Founders Day", note: "Ward closed")

    text = render_text(Date.new(2026, 3, 1))

    assert_includes text, "Founders Day"
    assert_includes text, "Ward closed"
  end

  test "shows a comment-only day note that has no name" do
    Holiday.create!(date: Date.new(2026, 3, 5), holiday: false, name: nil, note: "Staff meeting 15:00\nRoom 2")

    text = render_text(Date.new(2026, 3, 1))

    assert_includes text, "Staff meeting 15:00 Room 2"
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

  test "uses only black, white and grays so it prints cleanly on a monochrome printer" do
    # 2026-03-01 holds an emergency case and 2026-03-04 is an empty day, so
    # every colored element (header, day rows, emergency shading, placeholder)
    # is on the page.
    reader = PDF::Reader.new(StringIO.new(WeeklySurgerySchedulePdf.new(Date.new(2026, 3, 1)).render))
    colors = reader.pages.flat_map { |page| page.raw_content.scan(/(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (?:rg|RG|scn|SCN)\b/) }

    assert_not_empty colors
    tinted = colors.reject { |r, g, b| r == g && g == b }
    assert_empty tinted, "non-gray colors in PDF: #{tinted.uniq.inspect}"
  end

  test "shows the referral source under the patient when a referred hospitalization covers the surgery date" do
    date = Date.new(2030, 1, 8)
    patient = new_patient
    create_hospitalization(patient, scheduled_admission_date: date - 1, discharge_date: date + 3,
                                    outcome: "recovered", referred_from: "City Clinic")
    create_surgery(patient, date)

    assert_includes render_text(Date.new(2030, 1, 7)), "Referred From: City Clinic"
    assert_includes render_text(Date.new(2030, 1, 7), locale: :ja), "紹介元: City Clinic"
  end

  test "leaves out the referral line when no referred hospitalization covers the surgery" do
    date = Date.new(2030, 1, 8)
    create_surgery(new_patient, date)
    other = new_patient
    create_hospitalization(other, scheduled_admission_date: date + 10, referred_from: "Later Clinic")
    create_surgery(other, date)

    text = render_text(Date.new(2030, 1, 7))

    assert_not_includes text, "Referred From"
    assert_not_includes text, "Later Clinic"
  end

  test "referral lookup adds no queries per surgery" do
    date = Date.new(2030, 1, 8)
    create_surgery(new_patient, date)
    one = count_queries { WeeklySurgerySchedulePdf.new(Date.new(2030, 1, 7)).render }
    3.times do
      patient = new_patient
      create_hospitalization(patient, scheduled_admission_date: date, referred_from: "Clinic")
      create_surgery(patient, date)
    end
    many = count_queries { WeeklySurgerySchedulePdf.new(Date.new(2030, 1, 7)).render }

    assert_equal one, many
  end

  private

    def new_patient
      @patient_sequence = (@patient_sequence || 0) + 1
      Patient.create!(name: "Pdf Test Patient #{@patient_sequence}", hospital_id: "PDF#{@patient_sequence}",
                      date_of_birth: Date.new(1980, 1, 1))
    end

    def create_surgery(patient, date)
      Surgery.create!(
        patient: patient, surgery_date: date, anesthesia_method: "General",
        surgery_procedure_selections_attributes: [ { surgery_procedure_id: surgery_procedures(:appendectomy).id } ]
      )
    end

    def create_hospitalization(patient, **attrs)
      Hospitalization.create!(
        { patient: patient, reason: "Pdf test reservation",
          hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:appendicitis).id } ] }.merge(attrs)
      )
    end

    def count_queries
      count = 0
      counter = ->(_name, _started, _finished, _unique_id, payload) do
        count += 1 unless payload[:cached] || payload[:name] == "SCHEMA"
      end

      ActiveRecord::Base.lease_connection.materialize_transactions
      ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
      end
      count
    end
end
