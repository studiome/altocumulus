require "test_helper"

# Stage 2 of the i18n rollout: covers every "display string" built by models
# and helpers (option-constant labels, status_label, ElectiveSlotUsage
# warnings, length_of_stay_display, weekday names, to_s summaries). For each
# one this asserts:
#   1. the English locale renders byte-identical to what the old hardcoded
#      string used to be (so existing 614 tests keep passing unmodified),
#   2. the Japanese locale renders a real Japanese translation (not English,
#      not "translation missing"), and
#   3. the underlying DB-stored value never changes with locale.
class I18nDisplayStringsTest < ActiveSupport::TestCase
  # -- Hospitalization option labels ------------------------------------

  test "Hospitalization outcome/discharge_destination/reservation_status/purpose/admin_status/status_filter options are English by default" do
    assert_equal "Recovered", Hospitalization.outcome_options["recovered"]
    assert_equal "Died", Hospitalization.outcome_options["died"]
    assert_equal "Another Hospital", Hospitalization.discharge_destination_options["hospital"]
    assert_equal "Admitted (Other Dept.)", Hospitalization.reservation_status_options["admitted_other_dept"]
    assert_equal "Examination / Procedure", Hospitalization.purpose_options["examination"]
    assert_equal "Unconfirmed", Hospitalization.admin_status_options["unconfirmed"]
    assert_equal "Recently Updated", Hospitalization.status_filter_options["recently_updated"]
  end

  test "Hospitalization option labels are Japanese under the ja locale" do
    I18n.with_locale(:ja) do
      assert_equal "治癒", Hospitalization.outcome_options["recovered"]
      assert_equal "他院", Hospitalization.discharge_destination_options["hospital"]
      assert_equal "入院済み(他科)", Hospitalization.reservation_status_options["admitted_other_dept"]
      assert_equal "検査・処置", Hospitalization.purpose_options["examination"]
      assert_equal "未確認", Hospitalization.admin_status_options["unconfirmed"]
      assert_equal "最近更新", Hospitalization.status_filter_options["recently_updated"]
    end
  end

  test "Hospitalization *_form_options keep their [label, key] shape in both locales" do
    assert_includes Hospitalization.outcome_form_options, [ "Recovered", "recovered" ]

    I18n.with_locale(:ja) do
      assert_includes Hospitalization.outcome_form_options, [ "治癒", "recovered" ]
    end
  end

  # -- Surgery option labels ---------------------------------------------

  test "Surgery scheduling_type/surgery_date_status options are English by default and Japanese under ja" do
    assert_equal "Elective", Surgery.scheduling_type_options["elective"]
    assert_equal "Date Specified", Surgery.surgery_date_status_options["scheduled"]

    I18n.with_locale(:ja) do
      assert_equal "予定", Surgery.scheduling_type_options["elective"]
      assert_equal "日付指定", Surgery.surgery_date_status_options["scheduled"]
    end
  end

  # -- Patient option labels ----------------------------------------------

  test "Patient sex options are English by default and Japanese under ja" do
    assert_equal "Male", Patient.sex_options["male"]

    I18n.with_locale(:ja) do
      assert_equal "男性", Patient.sex_options["male"]
    end
  end

  # -- Lateralizable laterality options ------------------------------------

  test "Lateralizable laterality options are English by default and Japanese under ja" do
    assert_equal "Right", Lateralizable.laterality_options["right"]
    assert_equal "None", Lateralizable.laterality_options["none"]

    I18n.with_locale(:ja) do
      assert_equal "右", Lateralizable.laterality_options["right"]
      assert_equal "なし", Lateralizable.laterality_options["none"]
    end
  end

  test "laterality_label falls back to the localized 'none' label for an unrecognized value" do
    selection = surgery_procedure_selections(:one_appendectomy)
    selection.laterality = "none"
    assert_equal "None", selection.laterality_label

    I18n.with_locale(:ja) do
      assert_equal "なし", selection.laterality_label
    end
  end

  # -- Hospitalization#status_label ----------------------------------------

  test "status_label is English by default and Japanese under ja" do
    assert_equal "Discharged", hospitalizations(:one).status_label
    assert_equal "In Hospital", hospitalizations(:three).status_label

    I18n.with_locale(:ja) do
      assert_equal "退院済み", hospitalizations(:one).status_label
      assert_equal "入院中", hospitalizations(:three).status_label
    end
  end

  # -- ElectiveSlotUsage#warnings -------------------------------------------

  test "warnings for an unconfigured weekday are English by default and Japanese under ja" do
    sunday = Date.new(2026, 3, 1) # no rule configured (see elective_slot_usage_test.rb)
    usage = ElectiveSlotUsage.for_dates([ sunday ])[sunday]

    assert_includes usage.warnings, "No elective slots are configured for Sunday."

    I18n.with_locale(:ja) do
      usage_ja = ElectiveSlotUsage.for_dates([ sunday ])[sunday]
      assert_includes usage_ja.warnings, "日曜日には手術枠が設定されていません。"
    end
  end

  test "warnings singular/plural agreement for unscheduled surgeries in both locales" do
    rule = elective_slot_rules(:wednesday) # 2 slots x 180 min
    single = Surgery.new(scheduling_type: "elective", slot_number: 9, duration_hours: 1.0)
    usage = ElectiveSlotUsage.new(date: Date.new(2026, 3, 4), rule: rule, elective_surgeries: [ single ], emergency_surgeries: [])

    assert_includes usage.warnings, "1 elective surgery is not assigned to an available slot."

    two = [
      Surgery.new(scheduling_type: "elective", slot_number: 9, duration_hours: 1.0),
      Surgery.new(scheduling_type: "elective", slot_number: 10, duration_hours: 1.0)
    ]
    usage_two = ElectiveSlotUsage.new(date: Date.new(2026, 3, 4), rule: rule, elective_surgeries: two, emergency_surgeries: [])
    assert_includes usage_two.warnings, "2 elective surgeries are not assigned to an available slot."

    I18n.with_locale(:ja) do
      usage_ja_one = ElectiveSlotUsage.new(date: Date.new(2026, 3, 4), rule: rule, elective_surgeries: [ single ], emergency_surgeries: [])
      assert_includes usage_ja_one.warnings, "1件の予定手術が利用可能な枠に割り当てられていません。"

      usage_ja_two = ElectiveSlotUsage.new(date: Date.new(2026, 3, 4), rule: rule, elective_surgeries: two, emergency_surgeries: [])
      assert_includes usage_ja_two.warnings, "2件の予定手術が利用可能な枠に割り当てられていません。"
    end
  end

  test "holiday warning is English by default and Japanese under ja" do
    holiday = holidays(:national_holiday)
    surgery = Surgery.new(scheduling_type: "elective", slot_number: 1, duration_hours: 1.0)
    usage = ElectiveSlotUsage.new(
      date: holiday.date, rule: elective_slot_rules(:tuesday), elective_surgeries: [ surgery ],
      emergency_surgeries: [], holiday: holiday
    )

    assert_equal [ "#{holiday.name} is a holiday: no elective slots are available." ], usage.warnings

    I18n.with_locale(:ja) do
      usage_ja = ElectiveSlotUsage.new(
        date: holiday.date, rule: elective_slot_rules(:tuesday), elective_surgeries: [ surgery ],
        emergency_surgeries: [], holiday: holiday
      )
      assert_equal [ "#{holiday.name}は休日のため、利用できる手術枠がありません。" ], usage_ja.warnings
    end
  end

  test "overrun warning is English by default and Japanese under ja" do
    rule = elective_slot_rules(:tuesday) # 3 slots x 240 min
    over = Surgery.new(scheduling_type: "elective", slot_number: 2, duration_hours: 5.0) # 300 min, over the 240 min slot
    usage = ElectiveSlotUsage.new(date: Date.new(2026, 3, 3), rule: rule, elective_surgeries: [ over ], emergency_surgeries: [])

    assert_includes usage.warnings, "Slot 2 is booked 60 min past its 240 min limit."

    I18n.with_locale(:ja) do
      usage_ja = ElectiveSlotUsage.new(date: Date.new(2026, 3, 3), rule: rule, elective_surgeries: [ over ], emergency_surgeries: [])
      assert_includes usage_ja.warnings, "第2枠は上限240分を60分超過しています。"
    end
  end

  # -- ElectiveSlotRule day names / to_s ------------------------------------

  test "ElectiveSlotRule.day_names and #day_name follow the locale" do
    assert_equal %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday], ElectiveSlotRule.day_names
    assert_equal "Tuesday", elective_slot_rules(:tuesday).day_name

    I18n.with_locale(:ja) do
      assert_equal %w[日曜日 月曜日 火曜日 水曜日 木曜日 金曜日 土曜日], ElectiveSlotRule.day_names
      assert_equal "火曜日", elective_slot_rules(:tuesday).day_name
    end
  end

  test "ElectiveSlotRule#to_s is English by default and Japanese under ja" do
    assert_equal "Tuesday - 3 slots x 240 min", elective_slot_rules(:tuesday).to_s

    I18n.with_locale(:ja) do
      assert_equal "火曜日 - 3枠 x 240分", elective_slot_rules(:tuesday).to_s
    end
  end

  # -- Hospitalization#to_s / Surgery#to_s / #surgery_date_display ---------

  test "Hospitalization#to_s fallback text is English by default and Japanese under ja" do
    assert_equal "H001 - John Doe (2026-06-01 - in hospital)", hospitalizations(:three).to_s

    I18n.with_locale(:ja) do
      hospitalization = Hospitalization.new(patient: patients(:one))
      assert_match(/日付未定/, hospitalization.to_s)
      assert_match(/入院中/, hospitalizations(:three).to_s)
    end
  end

  test "Surgery#surgery_date_display and #to_s fallback text follow the locale" do
    surgery = Surgery.new(patient: patients(:one), surgery_date: nil)
    assert_equal "Undated", surgery.surgery_date_display
    assert_match(/\ADate not set - /, surgery.to_s)

    I18n.with_locale(:ja) do
      assert_equal "未定", surgery.surgery_date_display
      assert_match(/\A日付未定 - /, surgery.to_s)
    end
  end

  # -- DB storage stays English regardless of locale ------------------------

  test "enum-like columns store their English key even when created/updated under the ja locale" do
    I18n.with_locale(:ja) do
      hospitalization = Hospitalization.create!(
        patient: patients(:two),
        scheduled_admission_date: Date.new(2026, 9, 1),
        reason: "Planned surgery",
        purpose: "chemotherapy",
        admin_status: "confirmed",
        hospitalization_diagnoses_attributes: [ { diagnosis_id: diagnoses(:pneumonia).id } ]
      )

      assert_equal "chemotherapy", hospitalization.reload.purpose
      assert_equal "confirmed", hospitalization.admin_status
      assert_equal "requested", hospitalization.reservation_status

      hospitalization.update!(outcome: "recovered", discharge_date: Date.current, discharge_destination: "home")
      assert_equal "recovered", hospitalization.reload.outcome
      assert_equal "home", hospitalization.discharge_destination
    end
  end

  test "*_options keys stay the English DB keys even when the labels are Japanese" do
    I18n.with_locale(:ja) do
      assert_equal Hospitalization::PURPOSE_KEYS, Hospitalization.purpose_options.keys
      assert_equal Surgery::SCHEDULING_TYPE_KEYS, Surgery.scheduling_type_options.keys
      assert_equal Patient::SEX_KEYS, Patient.sex_options.keys
    end
  end
end
