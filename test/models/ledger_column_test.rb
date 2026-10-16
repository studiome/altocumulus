require "test_helper"

class LedgerColumnTest < ActiveSupport::TestCase
  SURGERY_KEYS = %i[time_slot admission_dates patient age_sex diagnosis_procedure operator_assistant
                    duration_anesthesia team category reservation referral_adl status].freeze
  HOSPITALIZATION_KEYS = %i[admission_dates patient age_sex diagnosis_procedure_name purpose team category
                            reservation referral_adl status].freeze

  setup do
    @context = LedgerColumn::Context.new
  end

  def cell(subject, key, record, context = @context)
    LedgerColumn.find(subject, key).cell(record, context)
  end

  def kinds(segments)
    segments.map(&:kind)
  end

  def texts(segments)
    segments.map(&:text)
  end

  def linked_surgery(**hospitalization_attrs)
    hospitalization = hospitalizations(:one)
    hospitalization.update_columns(hospitalization_attrs) if hospitalization_attrs.any?
    surgery = surgeries(:one)
    surgery.update_columns(hospitalization_id: hospitalization.id)
    surgery.reload
  end

  # --- registry ---------------------------------------------------------

  test "the registry knows every surgery and hospitalization column" do
    assert_equal SURGERY_KEYS.sort, LedgerColumn.keys(:surgery).sort
    assert_equal HOSPITALIZATION_KEYS.sort, LedgerColumn.keys(:hospitalization).sort
  end

  test "find raises for an unknown key and for a key of the other subject" do
    assert_raises(KeyError) { LedgerColumn.find(:surgery, :nope) }
    assert_raises(KeyError) { LedgerColumn.find(:hospitalization, :time_slot) }
  end

  test "every column has a header label, a positive width and an upper label in both locales" do
    %i[surgery hospitalization].each do |subject|
      LedgerColumn.keys(subject).each do |key|
        column = LedgerColumn.find(subject, key)
        assert_operator column.width, :>, 0, "#{subject}/#{key} width"
        %i[en ja].each do |locale|
          I18n.with_locale(locale) do
            assert column.header_upper.present?, "#{subject}/#{key} upper header (#{locale})"
            assert_not_includes column.header_upper, "translation missing"
            assert_not_includes column.header_lower.to_s, "translation missing"
          end
        end
      end
    end
  end

  test "ledgers map to a subject and the configured columns, falling back to the built-in defaults" do
    assert_equal :surgery, LedgerColumn.subject_for(:operations_calendar)
    assert_equal :surgery, LedgerColumn.subject_for(:weekly_pdf)
    assert_equal :hospitalization, LedgerColumn.subject_for(:examination_calendar)

    assert_equal %i[time_slot patient diagnosis_procedure operator_assistant duration_anesthesia category referral_adl],
                 LedgerColumn.for_ledger(:operations_calendar).map(&:key)
    assert_equal %i[admission_dates patient age_sex diagnosis_procedure_name purpose reservation referral_adl status],
                 LedgerColumn.for_ledger(:examination_calendar).map(&:key)
  end

  test "for_ledger follows the site config order" do
    with_site_config("ledger_columns" => { "weekly_pdf" => %w[patient time_slot] }) do
      assert_equal %i[patient time_slot], LedgerColumn.for_ledger(:weekly_pdf).map(&:key)
      assert_equal 7, LedgerColumn.for_ledger(:operations_calendar).size
    end
  end

  # --- cell value object ------------------------------------------------

  test "plain_text flattens segments with the list separator and the parts with a newline" do
    cell = LedgerColumn::Cell.new(
      upper: [ LedgerColumn::Segment.new("A", :primary), LedgerColumn::Segment.new("B", :emergency) ],
      lower: [ LedgerColumn::Segment.new("C", :secondary) ]
    )
    sep = I18n.t("common.list_separator")
    assert_equal "A#{sep}B\nC", cell.plain_text
  end

  test "plain_text leaves out an empty part" do
    cell = LedgerColumn::Cell.new(upper: [], lower: [ LedgerColumn::Segment.new("C", :secondary) ])
    assert_equal "C", cell.plain_text
  end

  # --- surgery columns --------------------------------------------------

  test "surgery time_slot shows the start time over the slot number" do
    cell = cell(:surgery, :time_slot, surgeries(:three))
    assert_equal [ "09:00" ], texts(cell.upper)
    assert_equal [ :mono ], kinds(cell.upper)
    assert_equal [ "Slot 1" ], texts(cell.lower)
  end

  test "surgery time_slot shows the slot category label outside the regular slots" do
    surgery = surgeries(:three)
    surgery.slot_category = "off_slot"
    assert_equal [ surgery.slot_category_label ], texts(cell(:surgery, :time_slot, surgery).lower)
  end

  test "surgery time_slot shows a dash for an unassigned slot" do
    assert_equal [ I18n.t("common.none") ], texts(cell(:surgery, :time_slot, surgeries(:six)).lower)
  end

  test "surgery admission_dates shows scheduled over actual admission date of the hospitalization" do
    surgery = linked_surgery(scheduled_admission_date: Date.new(2026, 2, 27))
    cell = cell(:surgery, :admission_dates, surgery)
    assert_equal [ "2026-02-27" ], texts(cell.upper)
    assert_equal [ "2026-03-01" ], texts(cell.lower)
  end

  test "surgery admission_dates shows dashes without a hospitalization" do
    cell = cell(:surgery, :admission_dates, surgeries(:one))
    assert_equal [ "-" ], texts(cell.upper)
    assert_equal [ "-" ], texts(cell.lower)
  end

  test "surgery patient shows the hospital id over the name, linked when an href is given" do
    context = LedgerColumn::Context.new(href: ->(record) { "/surgeries/#{record.id}" })
    cell = cell(:surgery, :patient, surgeries(:three), context)
    assert_equal [ "H001" ], texts(cell.upper)
    assert_equal [ "John Doe" ], texts(cell.lower)
    assert_nil cell.upper.first.href
    assert_equal "/surgeries/#{surgeries(:three).id}", cell.lower.first.href
  end

  test "surgery patient has no link without an href and no referral" do
    cell = cell(:surgery, :patient, surgeries(:three))
    assert_nil cell.lower.first.href
    assert_equal "H001\nJohn Doe", cell.plain_text
  end

  test "surgery patient names a missing patient by id" do
    surgery = surgeries(:one)
    surgery.patient = nil
    assert_includes cell(:surgery, :patient, surgery).plain_text, "Patient ##{surgery.patient_id}"
  end

  test "surgery age_sex shows the age on the surgery date over the sex" do
    patient = surgeries(:one).patient # born 1980-01-01, surgery 2026-03-01
    patient.update_columns(sex: "female")
    cell = cell(:surgery, :age_sex, surgeries(:one).reload)
    assert_equal [ "46 y" ], texts(cell.upper)
    assert_equal [ "Female" ], texts(cell.lower)
  end

  test "surgery age_sex is a dash for age on an undated surgery and blank sex" do
    surgery = surgeries(:one)
    surgery.surgery_date = nil
    cell = cell(:surgery, :age_sex, surgery)
    assert_equal [ "-" ], texts(cell.upper)
    assert_empty cell.lower
  end

  test "surgery age_sex counts the birthday as reached on the day itself" do
    surgery = surgeries(:one)
    surgery.surgery_date = Date.new(2026, 1, 1)
    assert_equal [ "46 y" ], texts(cell(:surgery, :age_sex, surgery).upper)
    surgery.surgery_date = Date.new(2025, 12, 31)
    assert_equal [ "45 y" ], texts(cell(:surgery, :age_sex, surgery).upper)
  end

  test "surgery diagnosis_procedure shows diagnoses over procedures" do
    surgery = surgeries(:one)
    cell = cell(:surgery, :diagnosis_procedure, surgery)
    assert_equal [ surgery.diagnosis_names_display ], texts(cell.upper)
    assert_equal [ surgery.display_procedure_name ], texts(cell.lower)
    assert_equal [ :secondary ], kinds(cell.upper)
    assert_equal [ :primary ], kinds(cell.lower)
  end

  test "surgery operator_assistant shows the operator over the assistant" do
    surgery = surgeries(:one)
    surgery.operator_name = "Dr. Operator"
    surgery.assistant_name = "Dr. Assistant"
    cell = cell(:surgery, :operator_assistant, surgery)
    assert_equal [ "Dr. Operator" ], texts(cell.upper)
    assert_equal [ "Dr. Assistant" ], texts(cell.lower)
  end

  test "surgery operator_assistant shows a dash without an operator and no assistant line" do
    cell = cell(:surgery, :operator_assistant, surgeries(:one))
    assert_equal [ "-" ], texts(cell.upper)
    assert_empty cell.lower
  end

  test "surgery duration_anesthesia shows hours over the anesthesia method" do
    cell = cell(:surgery, :duration_anesthesia, surgeries(:one))
    assert_equal [ "1.5 h" ], texts(cell.upper)
    assert_equal [ "General" ], texts(cell.lower)
    surgery = surgeries(:one)
    surgery.duration_hours = nil
    assert_equal [ "-" ], texts(cell(:surgery, :duration_anesthesia, surgery).upper)
  end

  test "surgery team shows the team and the members of the term covering the surgery date" do
    with_site_config("features" => { "teams" => true }) do
      surgery = surgeries(:one)
      surgery.team = teams(:blue)
      surgery.surgery_date = Date.new(2026, 10, 20)
      cell = cell(:surgery, :team, surgery)
      assert_equal [ "Blue Team" ], texts(cell.upper)
      assert_equal [ :team ], kinds(cell.upper)
      assert_equal "blue", cell.upper.first.color
      assert_equal [ "Alpha(M), Bravo(S), Delta, Charlie" ], texts(cell.lower)
    end
  end

  test "surgery team falls back to the hospitalization's team and is empty without one" do
    with_site_config("features" => { "teams" => true }) do
      surgery = linked_surgery
      assert_empty cell(:surgery, :team, surgery).upper
      surgery.hospitalization.team = teams(:red)
      assert_equal [ "Red Team" ], texts(cell(:surgery, :team, surgery).upper)
    end
  end

  test "surgery team is empty while the teams feature is off" do
    surgery = surgeries(:one)
    surgery.team = teams(:blue)
    assert_empty cell(:surgery, :team, surgery).upper
  end

  test "surgery category of a plain elective surgery is a single scheduling badge" do
    cell = cell(:surgery, :category, surgeries(:three))
    assert_equal [ :scheduling ], kinds(cell.upper)
    assert_equal [ "Elective" ], texts(cell.upper)
    assert_empty cell.lower
  end

  test "surgery category marks an emergency surgery" do
    cell = cell(:surgery, :category, surgeries(:emergency_one))
    assert_equal [ :emergency ], kinds(cell.upper)
  end

  test "surgery category adds the emergency admission of the hospitalization" do
    surgery = linked_surgery(emergency_admission: true)
    cell = cell(:surgery, :category, surgery)
    assert_equal [ :scheduling, :emergency ], kinds(cell.upper)
    assert_includes texts(cell.upper).last, "Emergency"
  end

  test "surgery category shows a simultaneous slot with its partner department and an off-slot marker" do
    surgery = surgeries(:three)
    surgery.slot_category = "simultaneous"
    surgery.department = departments(:gynecology)
    cell = cell(:surgery, :category, surgery)
    assert_equal %i[scheduling partner_department off_slot], kinds(cell.upper)
    assert_includes texts(cell.upper)[1], "Gynecology"
  end

  test "surgery category shows a backup slot with partner department and intervention" do
    surgery = surgeries(:three)
    surgery.slot_category = "backup"
    surgery.department = departments(:gynecology)
    surgery.backup_intervention = "involved"
    text = texts(cell(:surgery, :category, surgery).upper)[1]
    assert_includes text, "Gynecology"
    assert_includes text, surgery.backup_intervention_label
  end

  test "surgery category shows an off-slot surgery as the off-slot badge only" do
    surgery = surgeries(:three)
    surgery.slot_category = "off_slot"
    cell = cell(:surgery, :category, surgery)
    assert_equal %i[scheduling off_slot], kinds(cell.upper)
    assert_includes texts(cell.upper)[1], surgery.slot_category_label
  end

  test "surgery category lower part has location with performing department, transfer and device" do
    surgery = linked_surgery(transfer_status: "transferred_in", source_department_id: departments(:gynecology).id)
    surgery.surgery_location = surgery_locations(:cath_lab)
    surgery.performing_department = departments(:gynecology)
    surgery.surgical_device = surgical_devices(:robot_a)
    cell = cell(:surgery, :category, surgery)
    assert_equal %i[location transfer device], kinds(cell.lower)
    assert_includes texts(cell.lower)[0], "Cath Lab"
    assert_includes texts(cell.lower)[0], "Gynecology"
    assert_includes texts(cell.lower)[1], "Gynecology"
    assert_includes texts(cell.lower)[1], Hospitalization.transfer_status_options["transferred_in"]
    assert_equal [ surgical_devices(:robot_a).name ], [ texts(cell.lower)[2] ]
  end

  test "surgery category leaves out transfer when there is none" do
    surgery = linked_surgery(transfer_status: "none")
    assert_empty cell(:surgery, :category, surgery).lower
  end

  test "surgery reservation shows submitted date over the doctor and who entered it when different" do
    surgery = linked_surgery(submitted_on: Date.new(2026, 2, 20),
                             reservation_doctor_id: users(:admin).id, created_by_id: users(:member).id)
    cell = cell(:surgery, :reservation, surgery)
    assert_equal [ "2026-02-20" ], texts(cell.upper)
    assert_equal [ users(:admin).name, "Entered by: #{users(:member).name}" ], texts(cell.lower)
  end

  test "surgery reservation leaves out the entered-by line when the creator is the doctor" do
    surgery = linked_surgery(reservation_doctor_id: users(:admin).id, created_by_id: users(:admin).id)
    assert_equal [ users(:admin).name ], texts(cell(:surgery, :reservation, surgery).lower)
  end

  test "surgery reservation is blank without a hospitalization" do
    cell = cell(:surgery, :reservation, surgeries(:one))
    assert_empty cell.upper
    assert_empty cell.lower
  end

  test "surgery referral_adl uses the linked hospitalization" do
    surgery = linked_surgery(referred_from: "City Clinic", adl: "Independent")
    cell = cell(:surgery, :referral_adl, surgery)
    assert_equal [ "City Clinic" ], texts(cell.upper)
    assert_equal [ "Independent" ], texts(cell.lower)
  end

  test "surgery referral_adl falls back to the lookup for an unlinked surgery" do
    hospitalizations(:one).update_columns(referred_from: "Riverside Clinic", adl: "Walker")
    surgery = surgeries(:one)
    lookup = SurgeryReferralLookup.new(patient_ids: [ surgery.patient_id ], dates: [ surgery.surgery_date ])
    context = LedgerColumn::Context.new(referral_lookup: lookup)
    cell = cell(:surgery, :referral_adl, surgery, context)
    assert_equal [ "Riverside Clinic" ], texts(cell.upper)
    assert_equal [ "Walker" ], texts(cell.lower)
  end

  test "surgery referral_adl is blank without a hospitalization or lookup" do
    cell = cell(:surgery, :referral_adl, surgeries(:one))
    assert_empty cell.upper
    assert_empty cell.lower
  end

  test "surgery status shows the reservation and admin status labels" do
    surgery = linked_surgery(reservation_status: "date_fixed", admin_status: "confirmed")
    cell = cell(:surgery, :status, surgery)
    assert_equal [ Hospitalization.reservation_status_options["date_fixed"] ], texts(cell.upper)
    assert_equal [ Hospitalization.admin_status_options["confirmed"] ], texts(cell.lower)
  end

  test "surgery status flags a surgery without a hospitalization as missing" do
    cell = cell(:surgery, :status, surgeries(:one))
    assert_equal [ :missing ], kinds(cell.upper)
  end

  # --- hospitalization columns -----------------------------------------

  test "hospitalization admission_dates shows scheduled over actual" do
    hospitalization = hospitalizations(:one)
    hospitalization.scheduled_admission_date = Date.new(2026, 2, 27)
    cell = cell(:hospitalization, :admission_dates, hospitalization)
    assert_equal [ "2026-02-27" ], texts(cell.upper)
    assert_equal [ "2026-03-01" ], texts(cell.lower)
  end

  test "hospitalization patient links to the hospitalization when an href is given" do
    context = LedgerColumn::Context.new(href: ->(record) { "/hospitalizations/#{record.id}" })
    cell = cell(:hospitalization, :patient, hospitalizations(:one), context)
    assert_equal [ "H001" ], texts(cell.upper)
    assert_equal "/hospitalizations/#{hospitalizations(:one).id}", cell.lower.first.href
  end

  test "hospitalization age_sex uses the effective admission date" do
    hospitalization = hospitalizations(:one) # patient born 1980-01-01, admitted 2026-03-01
    hospitalization.patient.update_columns(sex: "male")
    cell = cell(:hospitalization, :age_sex, hospitalization.reload)
    assert_equal [ "46 y" ], texts(cell.upper)
    assert_equal [ "Male" ], texts(cell.lower)
  end

  test "hospitalization diagnosis_procedure_name shows diagnoses over the procedure name" do
    hospitalization = hospitalizations(:one)
    hospitalization.procedure_name = "Upper endoscopy"
    cell = cell(:hospitalization, :diagnosis_procedure_name, hospitalization)
    assert_equal [ hospitalization.diagnosis_names_display ], texts(cell.upper)
    assert_equal [ "Upper endoscopy" ], texts(cell.lower)
  end

  test "hospitalization purpose shows the purpose over the scheduled procedure date" do
    hospitalization = hospitalizations(:one)
    hospitalization.purpose = "examination"
    hospitalization.scheduled_procedure_date = Date.new(2026, 3, 2)
    cell = cell(:hospitalization, :purpose, hospitalization)
    assert_equal [ Hospitalization.purpose_options["examination"] ], texts(cell.upper)
    assert_equal [ "2026-03-02" ], texts(cell.lower)
  end

  test "hospitalization team follows the feature toggle and the case date" do
    hospitalization = hospitalizations(:one)
    hospitalization.team = teams(:blue)
    hospitalization.scheduled_surgery_date = Date.new(2026, 10, 20)
    assert_empty cell(:hospitalization, :team, hospitalization).upper
    with_site_config("features" => { "teams" => true }) do
      cell = cell(:hospitalization, :team, hospitalization)
      assert_equal [ "Blue Team" ], texts(cell.upper)
      assert_equal [ "Alpha(M), Bravo(S), Delta, Charlie" ], texts(cell.lower)
    end
  end

  test "hospitalization category shows emergency admission over transfer" do
    hospitalization = hospitalizations(:one)
    hospitalization.emergency_admission = true
    hospitalization.transfer_status = "transferred_in"
    hospitalization.source_department = departments(:gynecology)
    cell = cell(:hospitalization, :category, hospitalization)
    assert_equal [ :emergency ], kinds(cell.upper)
    assert_equal [ :transfer ], kinds(cell.lower)
    assert_includes texts(cell.lower).first, "Gynecology"
  end

  test "hospitalization reservation, referral_adl and status read the record itself" do
    hospitalization = hospitalizations(:one)
    hospitalization.assign_attributes(submitted_on: Date.new(2026, 2, 20), referred_from: "City Clinic", adl: "Independent",
                                      reservation_status: "date_fixed", admin_status: "confirmed")
    assert_equal [ "2026-02-20" ], texts(cell(:hospitalization, :reservation, hospitalization).upper)
    assert_equal [ "City Clinic" ], texts(cell(:hospitalization, :referral_adl, hospitalization).upper)
    assert_equal [ "Independent" ], texts(cell(:hospitalization, :referral_adl, hospitalization).lower)
    assert_equal [ Hospitalization.reservation_status_options["date_fixed"] ], texts(cell(:hospitalization, :status, hospitalization).upper)
  end

  # --- preloads ---------------------------------------------------------

  test "includes_for merges the associations the given columns need" do
    columns = %i[team category].map { |key| LedgerColumn.find(:surgery, key) }
    includes = LedgerColumn.includes_for(columns)
    assert_kind_of Array, includes
    assert Surgery.includes(*includes).to_sql
  end
end
