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

  test "shows the referral source in the referral column when a referred hospitalization covers the surgery date" do
    date = Date.new(2030, 1, 8)
    patient = new_patient
    create_hospitalization(patient, scheduled_admission_date: date - 1, discharge_date: date + 3,
                                    outcome: "recovered", referred_from: "City Clinic")
    create_surgery(patient, date)

    assert_includes render_text(Date.new(2030, 1, 7)), "City Clinic"
    assert_includes render_text(Date.new(2030, 1, 7)), "Referred From"
    assert_includes render_text(Date.new(2030, 1, 7), locale: :ja), "紹介元"
  end

  test "leaves out the referral when no referred hospitalization covers the surgery" do
    date = Date.new(2030, 1, 8)
    create_surgery(new_patient, date)
    other = new_patient
    create_hospitalization(other, scheduled_admission_date: date + 10, referred_from: "Later Clinic")
    create_surgery(other, date)

    text = render_text(Date.new(2030, 1, 7))

    assert_not_includes text, "Later Clinic"
  end

  test "handles a surgery whose patient is missing without raising" do
    date = Date.new(2030, 1, 8)
    patient = new_patient
    surgery = create_surgery(patient, date)
    ActiveRecord::Base.connection.disable_referential_integrity { surgery.update_column(:patient_id, -1) }

    text = render_text(Date.new(2030, 1, 7))
    assert_includes text, "Patient #-1"
  end

  test "shows the partner department and the location of non-regular surgeries" do
    date = Date.new(2030, 1, 9)
    create_surgery(new_patient, date).update!(slot_category: "simultaneous", department: departments(:gynecology))
    create_surgery(new_patient, date).update!(slot_category: "off_slot", surgery_location: surgery_locations(:cath_lab))

    text = render_text(Date.new(2030, 1, 7))

    assert_includes text, "Gynecology"
    assert_includes text, "Cath Lab"
  end

  test "the day heading says when the slot count is overridden" do
    Holiday.create!(date: Date.new(2030, 1, 8), holiday: false, note: "Reduced", slot_count: 2, slot_duration_minutes: 120)

    assert_includes render_text(Date.new(2030, 1, 7)), "Slots: 2 (changed)"
    assert_includes render_text(Date.new(2030, 1, 7), locale: :ja), "枠 2（変更）"
    assert_not_includes render_text(Date.new(2030, 2, 4)), "changed"
  end

  test "department and location add no queries per surgery" do
    date = Date.new(2030, 1, 8)
    create_surgery(new_patient, date).update!(slot_category: "simultaneous", department: departments(:gynecology))
    create_surgery(new_patient, date).update!(slot_category: "off_slot", surgery_location: surgery_locations(:cath_lab),
                                              surgical_device: surgical_devices(:robot_a))
    one = count_queries { WeeklySurgerySchedulePdf.new(Date.new(2030, 1, 7)).render }
    3.times do
      create_surgery(new_patient, date).update!(slot_category: "off_slot", surgery_location: surgery_locations(:cath_lab))
    end
    many = count_queries { WeeklySurgerySchedulePdf.new(Date.new(2030, 1, 7)).render }

    assert_equal one, many
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

  test "linked hospitalizations add no queries per surgery" do
    date = Date.new(2030, 1, 8)
    link_new_surgery = lambda do
      patient = new_patient
      hospitalization = create_hospitalization(patient, scheduled_admission_date: date - 2, referred_from: "Clinic")
      create_surgery(patient, date).update!(hospitalization: hospitalization)
    end
    link_new_surgery.call
    one = count_queries { WeeklySurgerySchedulePdf.new(Date.new(2030, 1, 7)).render }
    3.times { link_new_surgery.call }
    many = count_queries { WeeklySurgerySchedulePdf.new(Date.new(2030, 1, 7)).render }

    assert_equal one, many
  end

  test "the header has two tiers and the columns follow the site config order" do
    config = { "ledger_columns" => { "weekly_pdf" => %w[patient time_slot] } }
    with_site_config(config) do
      text = render_text(Date.new(2026, 3, 1))

      assert_operator text.index("Patient ID"), :<, text.index("Start Time")
      assert_includes text, "Name"
      assert_includes text, "Slot"
      assert_not_includes text, "Operator"
      assert_includes text, "John Doe"
    end
  end

  test "renders the configured columns with their content" do
    config = { "features" => { "teams" => true },
               "ledger_columns" => { "weekly_pdf" => %w[patient age_sex diagnosis_procedure team category reservation referral_adl] } }
    date = Date.new(2026, 10, 20)
    patient = new_patient # born 1980-01-01 => 46 on the surgery date
    patient.update!(sex: "female")
    hospitalization = create_hospitalization(patient, scheduled_admission_date: date - 2, referred_from: "City Clinic",
                                                      adl: "Independent", team: teams(:blue), submitted_on: date - 10,
                                                      reservation_doctor: users(:admin), reservation_status: "date_fixed")
    surgery = create_surgery(patient, date)
    surgery.update!(hospitalization: hospitalization, team: teams(:blue), surgery_location: surgery_locations(:cath_lab),
                    surgical_device: surgical_devices(:robot_a))

    with_site_config(config) do
      text = render_text(date - 1)

      [ "46 y", "Female", "Blue Team", "Alpha(M), Bravo(S)", "Cath Lab", "Robot A", "City Clinic", "Independent",
        users(:admin).name, "2026-10-10" ].each do |expected|
        assert_includes text, expected
      end
    end
  end

  test "renders the admission date and status columns" do
    date = Date.new(2026, 10, 20)
    patient = new_patient
    hospitalization = create_hospitalization(patient, scheduled_admission_date: date - 2, reservation_status: "date_fixed")
    create_surgery(patient, date).update!(hospitalization: hospitalization)

    with_site_config("ledger_columns" => { "weekly_pdf" => %w[patient admission_dates status] }) do
      text = render_text(date - 1)

      assert_includes text, "2026-10-18"
      assert_includes text, Hospitalization.reservation_status_options["date_fixed"]
    end
  end

  test "an over-wide column set is scaled to fit the page" do
    all = LedgerColumn.keys(:surgery).map(&:to_s)
    with_site_config("features" => { "teams" => true }, "ledger_columns" => { "weekly_pdf" => all }) do
      assert_operator LedgerColumn.for_ledger(:weekly_pdf).sum(&:width), :>, 790
      assert_nothing_raised { WeeklySurgerySchedulePdf.new(Date.new(2026, 3, 1)).render }
      assert_includes render_text(Date.new(2026, 3, 1)), "John Doe"
    end
  end

  test "column widths use the registry defaults, the last column taking the remainder" do
    widths = WeeklySurgerySchedulePdf.new(Date.new(2026, 3, 1)).column_widths(LedgerColumn.for_ledger(:weekly_pdf), 785.89)

    defaults = LedgerColumn.for_ledger(:weekly_pdf).map(&:width)
    assert_equal defaults[0...-1], widths[0...-1]
    assert_in_delta 785.89, widths.sum, 0.001
    assert_operator widths.last, :>=, defaults.last
  end

  test "column widths shrink proportionally when the defaults exceed the printable width" do
    columns = LedgerColumn.keys(:surgery).reject { |key| key == :team }.map { |key| LedgerColumn.find(:surgery, key) }
    widths = WeeklySurgerySchedulePdf.new(Date.new(2026, 3, 1)).column_widths(columns, 600)

    assert_operator widths.sum, :<=, 600
    assert_in_delta 600, widths.sum, 0.1
    ratio = widths.first / columns.first.width
    columns.zip(widths).each { |column, width| assert_in_delta ratio * column.width, width, 0.02 }
  end

  test "category, location and team columns add no queries per surgery" do
    config = { "features" => { "teams" => true },
               "ledger_columns" => { "weekly_pdf" => LedgerColumn.keys(:surgery).map(&:to_s) } }
    date = Date.new(2030, 1, 8)
    add = lambda do
      patient = new_patient
      hospitalization = create_hospitalization(patient, scheduled_admission_date: date - 1, referred_from: "Clinic",
                                                        team: teams(:blue), reservation_doctor: users(:admin), created_by: users(:member),
                                                        transfer_status: "transferred_in", source_department: departments(:gynecology))
      create_surgery(patient, date).update!(hospitalization: hospitalization, team: teams(:red), surgery_location: surgery_locations(:cath_lab),
                                            surgical_device: surgical_devices(:robot_a), performing_department: departments(:gynecology))
    end
    with_site_config(config) do
      add.call
      one = count_queries { WeeklySurgerySchedulePdf.new(Date.new(2030, 1, 7)).render }
      3.times { add.call }
      many = count_queries { WeeklySurgerySchedulePdf.new(Date.new(2030, 1, 7)).render }

      assert_equal one, many
    end
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
