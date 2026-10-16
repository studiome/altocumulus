# Clearly fictional demo records so the UI can be reviewed in development
# (`bin/rails dev:demo_data`). Everything is found-or-created by a natural key
# (login id, hospital id, name, a marker in the clinical comment), so running it
# again adds nothing. It refuses to run outside development.
#
# Cases are built from coherent diagnosis/procedure pairs (see Pair), so no
# patient is booked for a procedure that does not treat their diagnosis.
# Records the task created are recognized by the "デモデータ #NN" marker in a
# hospitalization's clinical comment (and the demo patient it belongs to).
# With `refresh: true` a re-run rewrites the clinical content of exactly those
# records in place (diagnoses, procedures, dates, slot category, referral...);
# anything without the marker is never touched.
#
# The data is laid out relative to the date it is run: team terms around today,
# hospitalizations and their surgeries over the following six weeks.
class DevDemoData
  class NotDevelopmentError < StandardError; end

  PASSWORD = "password".freeze
  MARKER = "デモデータ".freeze

  USERS = [
    [ "荒井 健一", "arai" ], [ "原口 誠", "haraguchi" ], [ "園田 美咲", "sonoda" ], [ "斎木 直樹", "saiki" ],
    [ "石橋 拓也", "ishibashi" ], [ "内田 沙織", "uchida" ], [ "大塚 圭", "otsuka" ], [ "川村 亮", "kawamura" ],
    [ "北条 彩", "hojo" ], [ "工藤 悠", "kudo" ]
  ].map { |name, slug| { name: name, slug: "demo-#{slug}", login_id: "demo-#{slug}@example.com" } }.freeze

  # name, color, members as [display name, role, user slug or nil]. Members
  # without a slug have no account.
  TEAMS = [
    { name: "青チーム", color: "blue",
      members: [ [ "荒井", "main", "arai" ], [ "原口", "sub", "haraguchi" ], [ "園田", "member", nil ], [ "斎木", "member", "saiki" ] ] },
    { name: "赤チーム", color: "red",
      members: [ [ "石橋", "main", "ishibashi" ], [ "内田", "sub", "uchida" ], [ "大塚", "member", nil ], [ "川村", "member", nil ] ] },
    { name: "緑チーム", color: "green",
      members: [ [ "北条", "main", "hojo" ], [ "工藤", "sub", "kudo" ], [ "渡辺", "member", nil ], [ "松岡", "member", nil ] ] },
    { name: "橙チーム", color: "orange",
      members: [ [ "村上", "main", nil ], [ "坂本", "sub", nil ], [ "西田", "member", nil ], [ "森田", "member", nil ] ] }
  ].freeze

  DEPARTMENTS = %w[消化器外科 循環器内科 放射線科].freeze
  LOCATIONS = [ { name: "手術室" }, { name: "ハイブリッド室" }, { name: "カテ室", asks_performing_department: true } ].freeze
  DEVICES = [ "手術支援ロボットA", "手術支援ロボットB" ].freeze

  # A diagnosis with the procedure that treats it, and how the case is usually
  # run (anesthesia, hours, where, whether a surgical robot is used). Every demo
  # case is built from one of these, so a patient with a prostate cancer is
  # never booked for an appendectomy. `side` is the laterality of the diagnosis
  # (dx_side) and of the procedure (proc_side); `performer` is the department
  # that performs an off-slot case in the cath lab.
  Pair = Data.define(:diagnosis, :dx_side, :procedure, :proc_side, :anesthesia, :hours, :place, :robotic, :performer)

  def self.pair(diagnosis, procedure, anesthesia, hours, dx_side: "none", proc_side: dx_side, place: :main, robotic: false, performer: nil)
    Pair.new(diagnosis: diagnosis, dx_side: dx_side, procedure: procedure, proc_side: proc_side, anesthesia: anesthesia,
             hours: hours, place: place, robotic: robotic, performer: performer)
  end

  # Elective cases in a regular slot, in the order they are booked.
  REGULAR_PAIRS = [
    pair("胆石症", "腹腔鏡下胆嚢摘出術", "全身麻酔", 2.0),
    pair("鼠径ヘルニア", "鼠径ヘルニア修復術", "脊椎麻酔", 1.0, dx_side: "right"),
    pair("前立腺癌", "ロボット支援下前立腺全摘除術", "全身麻酔", 3.5, robotic: true),
    pair("大腸癌", "ロボット支援下結腸切除術", "全身麻酔", 4.0, robotic: true),
    pair("虫垂炎", "腹腔鏡下虫垂切除術", "全身麻酔", 1.5),
    pair("腎腫瘍", "ロボット支援下腎部分切除術", "全身麻酔", 3.0, dx_side: "left", robotic: true),
    pair("腹部大動脈瘤", "ステントグラフト内挿術", "全身麻酔", 3.0, place: :hybrid),
    pair("子宮筋腫", "腹腔鏡下子宮全摘術", "全身麻酔", 2.5),
    pair("鼠径ヘルニア", "鼠径ヘルニア修復術", "脊椎麻酔", 1.0, dx_side: "left"),
    pair("直腸癌", "ロボット支援下直腸切除術", "全身麻酔", 5.0, robotic: true),
    pair("痔核", "痔核根治術", "脊椎麻酔", 1.0),
    pair("閉塞性動脈硬化症", "下肢動脈バイパス術", "全身麻酔", 4.0, dx_side: "right", place: :hybrid),
    pair("胃癌", "腹腔鏡下胃切除術", "全身麻酔", 4.0),
    pair("甲状腺腫瘍", "甲状腺葉切除術", "全身麻酔", 2.5, dx_side: "right"),
    pair("肝細胞癌", "腹腔鏡下肝部分切除術", "全身麻酔", 3.5),
    pair("膀胱癌", "経尿道的膀胱腫瘍切除術", "脊椎麻酔", 1.0)
  ].freeze

  EMERGENCY_PAIRS = [
    pair("虫垂炎", "腹腔鏡下虫垂切除術", "全身麻酔", 1.5),
    pair("腸閉塞", "腸閉塞解除術", "全身麻酔", 2.0),
    pair("急性胆嚢炎", "腹腔鏡下胆嚢摘出術", "全身麻酔", 2.0)
  ].freeze

  # Joint cases with the partner department (the cardiology department).
  SIMULTANEOUS_PAIRS = [
    pair("閉塞性動脈硬化症", "下肢動脈バイパス術", "全身麻酔", 4.0, dx_side: "left", place: :hybrid),
    pair("腹部大動脈瘤", "ステントグラフト内挿術", "全身麻酔", 3.0, place: :hybrid)
  ].freeze

  # Surgical standby for the partner department's catheter procedures.
  BACKUP_PAIRS = [
    pair("大動脈弁狭窄症", "経カテーテル大動脈弁留置術", "全身麻酔", 3.0, place: :hybrid),
    pair("狭心症", "経皮的冠動脈形成術", "局所麻酔", 2.0, place: :hybrid)
  ].freeze

  # Catheter-lab cases outside the regular slots, done by another department.
  OFF_SLOT_PAIRS = [
    pair("狭心症", "経皮的冠動脈形成術", "局所麻酔", 1.5, place: :cath, performer: "循環器内科"),
    pair("閉塞性動脈硬化症", "経皮的血管形成術", "局所麻酔", 1.5, dx_side: "right", place: :cath, performer: "放射線科")
  ].freeze

  # Admissions without surgery: examination, chemotherapy, examination.
  EXAM_PAIRS = [
    pair("胃癌", "上部消化管内視鏡検査", "局所麻酔", 0.5),
    pair("大腸癌", "化学療法", "局所麻酔", 0.5),
    pair("狭心症", "心臓カテーテル検査", "局所麻酔", 1.0)
  ].freeze

  ALL_PAIRS = (REGULAR_PAIRS + EMERGENCY_PAIRS + SIMULTANEOUS_PAIRS + BACKUP_PAIRS + OFF_SLOT_PAIRS + EXAM_PAIRS).freeze
  DIAGNOSES = ALL_PAIRS.map(&:diagnosis).uniq.freeze
  PROCEDURES = (ALL_PAIRS - EXAM_PAIRS).map(&:procedure).uniq.freeze

  REFERRAL_SOURCES = %w[近隣クリニックA 近隣クリニックB 市立総合病院 近隣クリニックC].freeze

  # Which of the first surgery days (0 = the first one after today) a joint,
  # backup or off-slot case sits on, so the first week shows each of them.
  SPECIAL_DAY_INDEXES = { off_slot: [ 0, 4 ], simultaneous: [ 1, 5 ], backup: [ 2, 6 ] }.freeze

  FAMILY_NAMES = %w[青山 池田 石井 上野 遠藤 岡田 加藤 木下 久保 小林 近藤 佐野 柴田 杉山 関口 高田 竹内 辻 土屋 長井
                    中川 野口 橋本 平野 福田 星野 堀 三浦 宮本 森下 安田 山崎 横山 吉村 和田].freeze
  GIVEN_NAMES = %w[太郎 花子 一郎 美咲 健太 愛 大輔 結衣 翔 優子 誠 明美 拓海 由美 隆 恵 剛 久美子 修 直美].freeze
  PATIENT_NAMES = FAMILY_NAMES.each_with_index.map { |family, i| "#{family} #{GIVEN_NAMES[i % GIVEN_NAMES.size]}" }.freeze

  COUNTED = [ User, Department, SurgeryLocation, SurgicalDevice, Team, TeamTerm, TeamTermMember, Patient,
              PatientDiagnosis, Hospitalization, Surgery, Holiday, ElectiveSlotRule, Diagnosis, SurgeryProcedure ].freeze

  # Returns how many rows of each kind this run created, keyed like
  # { users: 10, patients: 35, ... }, plus refreshed_cases: how many existing
  # demo cases a `refresh: true` run changed.
  def self.run(environment: Rails.env, today: Date.current, refresh: false)
    new(environment: environment, today: today, refresh: refresh).run
  end

  def initialize(environment:, today:, refresh: false)
    raise NotDevelopmentError, "dev:demo_data only runs in development (current: #{environment})" unless environment.to_s == "development"

    @today = today
    @refresh = refresh
    @refreshed_cases = 0
  end

  def run
    before = counts
    ActiveRecord::Base.transaction do
      @users = create_users
      create_masters
      create_slot_rules
      create_clinical_vocabulary
      @teams = create_teams
      @kinds = plan
      @pairs = @kinds.each_index.map { |index| pair_for(index) }
      @patients = create_patients
      create_holidays
      create_cases
    end
    counts.to_h { |model, count| [ model.model_name.plural.to_sym, count - before.fetch(model) ] }.merge(refreshed_cases: @refreshed_cases)
  end

  private

    def counts
      COUNTED.to_h { |model| [ model, model.count ] }
    end

    def create_users
      USERS.to_h do |attrs|
        login_id = User.identifier_username? ? attrs[:slug] : attrs[:login_id]
        user = User.find_by(login_id: login_id) ||
               User.create!(login_id: login_id, name: attrs[:name], password: PASSWORD, locale: "ja")
        [ attrs[:slug].delete_prefix("demo-"), user ]
      end
    end

    def create_masters
      DEPARTMENTS.each { |name| Department.create!(name: name) } if Department.none?
      LOCATIONS.each { |attrs| SurgeryLocation.create!(attrs) } if SurgeryLocation.none?
      DEVICES.each { |name| SurgicalDevice.create!(name: name) } if SurgicalDevice.none?

      @departments = Department.active.ordered.to_a
      @partner_department = department_named("循環器内科") || @departments.second || @departments.first
      @locations = SurgeryLocation.active.ordered.to_a
      @cath_lab = @locations.find(&:asks_performing_department) || @locations.last
      @hybrid_room = @locations.find { |l| l.name.match?(/ハイブリッド|hybrid/i) } || @locations.second || @locations.first
      @main_room = (@locations - [ @cath_lab, @hybrid_room ]).first || @locations.first
      @devices = SurgicalDevice.active.ordered.to_a
    end

    def department_named(name)
      @departments.find { |department| department.name == name }
    end

    def create_slot_rules
      return if ElectiveSlotRule.exists?

      { 1 => 2.5, 2 => 2.5, 4 => 3.5 }.each do |wday, slots|
        ElectiveSlotRule.create!(day_of_week: wday, slot_count: slots, slot_duration_minutes: 480)
      end
    end

    def create_clinical_vocabulary
      @diagnoses = DIAGNOSES.to_h { |name| [ name, Diagnosis.find_or_create_by!(name: name) ] }
      @procedures = PROCEDURES.to_h { |name| [ name, SurgeryProcedure.find_or_create_by!(name: name) ] }
    end

    def create_teams
      TEAMS.map do |attrs|
        team = Team.find_or_create_by!(name: attrs[:name]) { |t| t.color = attrs[:color] }
        create_terms(team, attrs[:members])
        team
      end
    end

    # The term covering today and the one after it (main and sub swapped, as
    # the real rotation does), unless the team already has terms there.
    def create_terms(team, members)
      current = team.term_for(@today) || team.team_terms.create!(
        starts_on: @today.beginning_of_month, ends_on: (@today.beginning_of_month + 2.months - 1.day),
        team_term_members_attributes: members.each_with_index.map do |(name, role, slug), index|
          { name: name, role: role, user_id: slug && @users.fetch(slug).id, position: index + 1 }
        end
      )
      following = team.team_terms.find_by(starts_on: current.ends_on + 1)
      current.build_successor.save! unless following || team.term_for(current.ends_on + 1)
    end

    def create_patients
      PATIENT_NAMES.each_with_index.map do |name, index|
        patient = Patient.find_or_initialize_by(hospital_id: demo_hospital_id(index))
        if patient.new_record?
          patient.update!(name: name, name_kana: nil, sex: index.even? ? "male" : "female",
                          date_of_birth: Date.new(1940 + (index * 7) % 55, 1 + index % 12, 1 + (index * 3) % 27))
        end
        ensure_patient_diagnosis(patient, index)
        patient
      end
    end

    def demo_hospital_id(index)
      format("9000%04d", index + 1)
    end

    # A demo patient is one with a demo ID and the demo name for that number,
    # so a real record that happens to share an ID is never rewritten.
    def demo_patient?(patient, index)
      patient.hospital_id == demo_hospital_id(index) && patient.name == PATIENT_NAMES[index]
    end

    # The patient's diagnosis is the case's (see refresh_patient_diagnosis for
    # rewriting an existing one).
    def ensure_patient_diagnosis(patient, index)
      pair = @pairs[index] || REGULAR_PAIRS.first
      return if patient.patient_diagnoses.exists?

      patient.patient_diagnoses.create!(diagnosis: @diagnoses.fetch(pair.diagnosis), laterality: pair.dx_side, diagnosed_on: @today - 30 - index)
    end

    # Refresh: the demo patient's first diagnosis (the one this task created)
    # becomes the case's; diagnoses someone added later are left alone.
    def refresh_patient_diagnosis(patient, pair)
      existing = patient.patient_diagnoses.order(:id).first
      return unless existing

      existing.update!(diagnosis: @diagnoses.fetch(pair.diagnosis), laterality: pair.dx_side)
    end

    def create_holidays
      range = (@today + 1)..(@today + 42)
      closed = range.find { |d| d.monday? && d >= @today + 14 }
      conference = range.find { |d| d.tuesday? && d >= @today + 7 }
      note_day = range.find { |d| d.thursday? && d >= @today + 21 }
      {
        "#{MARKER} 休診日" => [ closed, { holiday: true } ],
        "#{MARKER} カンファレンス" => [ conference, { holiday: false, slot_count: 2, slot_duration_minutes: 480,
                                                         note: "午後は学会参加のため手術は2枠" } ],
        "#{MARKER} 病棟会議" => [ note_day, { holiday: false, note: "夕方に病棟会議" } ]
      }.each do |name, (date, attrs)|
        next if date.nil? || Holiday.exists?(name: name) || Holiday.exists?(date: date)

        Holiday.create!(name: name, date: date, **attrs)
      end
    end

    # --- hospitalizations and surgeries --------------------------------------

    def create_cases
      @rules = ElectiveSlotRule.by_day_of_week
      @holidays = Holiday.by_date((@today + 1)..(@today + 42))
      @surgery_days = (@today + 1..@today + 42).filter_map do |date|
        rule = ElectiveSlotRule.effective_for(date, @rules, @holidays)
        next if rule.nil? || @holidays[date]&.holiday?

        [ date, rule.total_slots ]
      end
      # Every (day, slot) in order: regular cases fill a day's slots before the
      # next day, so the first week is busy.
      @slot_sequence = @surgery_days.flat_map { |day, total| (1..total).map { |slot| [ day, slot ] } }
      @regular_count = 0

      @kinds.each_with_index { |kind, index| create_case(kind, index) }
    end

    # 34 cases: 22 elective regular surgeries, 3 emergencies, 2 joint cases in
    # another department's slot, 2 backup cases, 2 off-slot cath-lab cases,
    # then 3 admissions for examination or chemotherapy without surgery.
    def plan
      Array.new(22, :regular) + Array.new(3, :emergency) + Array.new(2, :simultaneous) + Array.new(2, :backup) +
        Array.new(2, :off_slot) + %i[examination chemotherapy examination]
    end

    # The diagnosis/procedure pair of case `index`: the n-th case of its kind.
    def pair_for(index)
      kind = @kinds[index]
      nth = @kinds[0...index].count { |earlier| same_pair_list?(earlier, kind) }
      list = { regular: REGULAR_PAIRS, emergency: EMERGENCY_PAIRS, simultaneous: SIMULTANEOUS_PAIRS, backup: BACKUP_PAIRS,
               off_slot: OFF_SLOT_PAIRS, examination: EXAM_PAIRS, chemotherapy: EXAM_PAIRS }.fetch(kind)
      list[nth % list.size]
    end

    def same_pair_list?(first, second)
      exam = %i[examination chemotherapy]
      first == second || (exam.include?(first) && exam.include?(second))
    end

    def create_case(kind, index)
      patient = @patients.fetch(index)
      marker = "#{MARKER} ##{format('%02d', index + 1)}"
      date = case_date(kind, index)
      pair = @pairs.fetch(index)
      hospitalization = Hospitalization.find_by(patient: patient, clinical_comment: marker)

      if hospitalization
        refresh_case(hospitalization, kind, index, patient, date, pair) if @refresh && demo_patient?(patient, index)
      else
        hospitalization = Hospitalization.create!(hospitalization_attributes(kind, index, patient, marker, date, pair))
        Surgery.create!(surgery_attributes(kind, index, patient, hospitalization, date, pair)) if surgery_kind?(kind)
      end
      # A hospitalization an earlier, interrupted run left without its surgery.
      return unless surgery_kind?(kind) && !hospitalization.surgeries.exists?

      Surgery.create!(surgery_attributes(kind, index, patient, hospitalization, date, pair))
    end

    # --- refresh ----------------------------------------------------------------

    HOSPITALIZATION_REFRESH_KEYS = %i[purpose referred_from adl emergency_admission procedure_name].freeze
    HOSPITALIZATION_DATE_KEYS = %i[scheduled_admission_date scheduled_surgery_date scheduled_procedure_date].freeze
    SURGERY_REFRESH_KEYS = %i[surgery_date anesthesia_method duration_hours scheduling_type slot_category slot_number operation_order
                              surgery_location surgical_device performing_department department backup_intervention].freeze

    # Rewrites the clinical content of one demo case from the current plan:
    # the patient's demo diagnosis, the hospitalization's purpose, dates,
    # referral and diagnosis, and the surgery's procedure, slot and category.
    # Who reserved it, its status, team and transfer are not touched.
    def refresh_case(hospitalization, kind, index, patient, date, pair)
      before = fingerprint(hospitalization)
      refresh_patient_diagnosis(patient, pair)
      refresh_hospitalization(hospitalization, kind, index, patient, date, pair)
      surgery = hospitalization.surgeries.order(:id).first
      refresh_surgery(surgery, kind, index, patient, hospitalization, date, pair) if surgery && surgery_kind?(kind)
      @refreshed_cases += 1 unless fingerprint(hospitalization) == before
    end

    def refresh_hospitalization(hospitalization, kind, index, patient, date, pair)
      attrs = hospitalization_attributes(kind, index, patient, nil, date, pair)
      keys = HOSPITALIZATION_REFRESH_KEYS + (hospitalization.admission_date ? [] : HOSPITALIZATION_DATE_KEYS)
      hospitalization.update!(attrs.slice(*keys))
      sync_hospitalization_diagnosis(hospitalization, pair)
    end

    def sync_hospitalization_diagnosis(hospitalization, pair)
      diagnosis = @diagnoses.fetch(pair.diagnosis)
      existing = hospitalization.hospitalization_diagnoses.order(:id).first
      if existing.nil?
        hospitalization.hospitalization_diagnoses.create!(diagnosis: diagnosis)
      elsif existing.diagnosis_id != diagnosis.id
        existing.update!(diagnosis: diagnosis)
      end
    end

    def refresh_surgery(surgery, kind, index, patient, hospitalization, date, pair)
      attrs = surgery_attributes(kind, index, patient, hospitalization, date, pair)
      selection = attrs[:surgery_procedure_selections_attributes].first
      first = surgery.surgery_procedure_selections.first
      selection = selection.merge(id: first.id) if first
      surgery.update!(attrs.slice(*SURGERY_REFRESH_KEYS).merge(surgery_procedure_selections_attributes: [ selection ],
                                                               patient_diagnoses: patient.patient_diagnoses.to_a))
    end

    def fingerprint(hospitalization)
      surgery = hospitalization.surgeries.order(:id).first
      [ hospitalization.reload.attributes.except("updated_at"),
        hospitalization.hospitalization_diagnoses.order(:id).pluck(:diagnosis_id),
        surgery&.reload&.attributes&.except("updated_at"),
        surgery&.surgery_procedure_selections&.reload&.pluck(:surgery_procedure_id, :laterality),
        hospitalization.patient.patient_diagnoses.order(:id).pluck(:diagnosis_id, :laterality) ]
    end

    def surgery_kind?(kind)
      %i[regular emergency simultaneous backup off_slot].include?(kind)
    end

    def case_date(kind, index)
      nth = @kinds[0...index].count(kind)
      case kind
      when :emergency then @today + 3 + nth * 7
      when :examination, :chemotherapy then next_weekday(@today + 4 + (index - 29) * 5)
      when :regular
        day, @slot = @slot_sequence[@regular_count % @slot_sequence.size]
        @regular_count += 1
        day
      else
        @surgery_days[SPECIAL_DAY_INDEXES.fetch(kind)[nth] % @surgery_days.size].first
      end
    end

    def next_weekday(date)
      date += 1 while date.saturday? || date.sunday?
      date
    end

    def hospitalization_attributes(kind, index, patient, marker, date, pair)
      user = @users.values[index % @users.size]
      attrs = {
        patient: patient, clinical_comment: marker, reservation_doctor: user, attending_doctor: user.name,
        reservation_status: Hospitalization::RESERVATION_STATUS_KEYS[index % 4],
        admin_status: (index % 3).zero? ? "confirmed" : "unconfirmed",
        scheduled_admission_date: [ date - ((index % 2).zero? ? 1 : 0), @today ].max,
        submitted_on: @today - (index % 10), planned_days: 3 + index % 6,
        referred_from: (index % 3).zero? ? REFERRAL_SOURCES[(index / 3) % REFERRAL_SOURCES.size] : nil,
        adl: adl_for(index),
        team: ((index % 9) == 8 && !SiteConfig.current.required_fields(:hospitalization).include?(:team_id)) ? nil : @teams[index % @teams.size],
        hospitalization_diagnoses_attributes: [ { diagnosis_id: @diagnoses.fetch(pair.diagnosis).id } ],
        procedure_name: nil, scheduled_procedure_date: nil, scheduled_surgery_date: nil, emergency_admission: false
      }
      attrs.merge!(purpose_attributes(kind, index, date, pair))
      attrs.merge!(transfer_attributes(index))
      attrs[:emergency_admission] = true if kind == :emergency
      attrs
    end

    def adl_for(index)
      return "自立" if index.even?

      index % 4 == 1 ? "一部介助" : nil
    end

    def purpose_attributes(kind, index, date, pair)
      case kind
      when :examination
        { purpose: "examination", scheduled_procedure_date: date, procedure_name: pair.procedure, scheduled_admission_date: date }
      when :chemotherapy
        { purpose: "chemotherapy", scheduled_procedure_date: date, procedure_name: "#{pair.procedure}(第#{index % 4 + 1}コース)",
          scheduled_admission_date: date }
      when :off_slot
        { purpose: "examination", scheduled_procedure_date: date, procedure_name: pair.procedure, scheduled_admission_date: date }
      when :emergency
        { purpose: "surgery", scheduled_surgery_date: date, scheduled_admission_date: date, reservation_status: "admitted" }
      else
        { purpose: "surgery", scheduled_surgery_date: date }
      end
    end

    def transfer_attributes(index)
      if (index % 6) == 2
        { transfer_status: "transferred_in", source_department: @partner_department }
      elsif (index % 11) == 4
        { transfer_status: "operated_without_transfer", source_department: @departments.first }
      else
        {}
      end
    end

    def surgery_attributes(kind, index, patient, hospitalization, date, pair)
      attrs = {
        patient: patient, hospitalization: hospitalization, surgery_date: date,
        anesthesia_method: pair.anesthesia, duration_hours: pair.hours,
        operator_name: @users.values[(index + 1) % @users.size].name, assistant_name: @users.values[(index + 2) % @users.size].name,
        scheduling_type: kind == :emergency ? "emergency" : "elective",
        slot_category: %i[simultaneous backup off_slot].include?(kind) ? kind.to_s : "regular",
        surgery_location: location_for(pair), start_time: format("%02d:00", 9 + index % 4),
        patient_diagnoses: patient.patient_diagnoses.to_a,
        surgery_procedure_selections_attributes: [ { surgery_procedure_id: @procedures.fetch(pair.procedure).id, laterality: pair.proc_side } ],
        surgical_device: (@devices[index % @devices.size] if pair.robotic), performing_department: nil, department: nil,
        backup_intervention: nil, slot_number: nil, operation_order: nil
      }
      attrs.merge(slot_attributes(kind, index, pair))
    end

    def location_for(pair)
      { main: @main_room, hybrid: @hybrid_room, cath: @cath_lab }.fetch(pair.place)
    end

    def slot_attributes(kind, index, pair)
      case kind
      when :regular then { slot_number: @slot, operation_order: @slot }
      when :simultaneous then { department: @partner_department }
      when :backup then { department: @partner_department, backup_intervention: index.even? ? "involved" : "not_involved" }
      when :off_slot then { performing_department: department_named(pair.performer) || @departments.third || @partner_department }
      else {}
      end
    end
end
