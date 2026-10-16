# Clearly fictional demo records so the UI can be reviewed in development
# (`bin/rails dev:demo_data`). Everything is found-or-created by a natural key
# (login id, hospital id, name, a marker in the clinical comment), so running it
# again adds nothing. It refuses to run outside development.
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

  DIAGNOSES = %w[胆石症 鼠径ヘルニア 虫垂炎 大腸癌 子宮筋腫 狭心症 前立腺癌 腎腫瘍].freeze
  PROCEDURES = %w[腹腔鏡下胆嚢摘出術 鼠径ヘルニア修復術 腹腔鏡下虫垂切除術 腹腔鏡下結腸切除術
                  子宮全摘術 経皮的冠動脈形成術 ロボット支援下前立腺全摘除術 ロボット支援下腎部分切除術].freeze
  ROBOTIC_PROCEDURES = [ "ロボット支援下前立腺全摘除術", "ロボット支援下腎部分切除術" ].freeze

  FAMILY_NAMES = %w[青山 池田 石井 上野 遠藤 岡田 加藤 木下 久保 小林 近藤 佐野 柴田 杉山 関口 高田 竹内 辻 土屋 長井
                    中川 野口 橋本 平野 福田 星野 堀 三浦 宮本 森下 安田 山崎 横山 吉村 和田].freeze
  GIVEN_NAMES = %w[太郎 花子 一郎 美咲 健太 愛 大輔 結衣 翔 優子 誠 明美 拓海 由美 隆 恵 剛 久美子 修 直美].freeze
  PATIENT_NAMES = FAMILY_NAMES.each_with_index.map { |family, i| "#{family} #{GIVEN_NAMES[i % GIVEN_NAMES.size]}" }.freeze

  ANESTHESIA = %w[全身麻酔 脊椎麻酔 局所麻酔].freeze
  EXAM_NAMES = [ "上部消化管内視鏡検査", "大腸内視鏡検査", "心臓カテーテル検査", "造影CT精査" ].freeze
  COUNTED = [ User, Department, SurgeryLocation, SurgicalDevice, Team, TeamTerm, TeamTermMember, Patient,
              PatientDiagnosis, Hospitalization, Surgery, Holiday, ElectiveSlotRule, Diagnosis, SurgeryProcedure ].freeze

  # Returns how many rows of each kind this run created, keyed like
  # { users: 10, patients: 35, ... }.
  def self.run(environment: Rails.env, today: Date.current)
    new(environment: environment, today: today).run
  end

  def initialize(environment:, today:)
    raise NotDevelopmentError, "dev:demo_data only runs in development (current: #{environment})" unless environment.to_s == "development"

    @today = today
  end

  def run
    before = counts
    ActiveRecord::Base.transaction do
      @users = create_users
      create_masters
      create_slot_rules
      create_clinical_vocabulary
      @teams = create_teams
      @patients = create_patients
      create_holidays
      create_cases
    end
    counts.to_h { |model, count| [ model.model_name.plural.to_sym, count - before.fetch(model) ] }
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
      @partner_department = @departments.second || @departments.first
      @locations = SurgeryLocation.active.ordered.to_a
      @cath_lab = @locations.find(&:asks_performing_department) || @locations.last
      @hybrid_room = @locations.find { |l| l.name.match?(/ハイブリッド|hybrid/i) } || @locations.second || @locations.first
      @main_room = (@locations - [ @cath_lab, @hybrid_room ]).first || @locations.first
      @devices = SurgicalDevice.active.ordered.to_a
    end

    def create_slot_rules
      return if ElectiveSlotRule.exists?

      { 1 => 2.5, 2 => 2.5, 4 => 3.5 }.each do |wday, slots|
        ElectiveSlotRule.create!(day_of_week: wday, slot_count: slots, slot_duration_minutes: 480)
      end
    end

    def create_clinical_vocabulary
      @diagnoses = DIAGNOSES.map { |name| Diagnosis.find_or_create_by!(name: name) }
      @procedures = PROCEDURES.map { |name| SurgeryProcedure.find_or_create_by!(name: name) }
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
        patient = Patient.find_or_initialize_by(hospital_id: format("9000%04d", index + 1))
        if patient.new_record?
          patient.update!(name: name, name_kana: nil, sex: index.even? ? "male" : "female",
                          date_of_birth: Date.new(1940 + (index * 7) % 55, 1 + index % 12, 1 + (index * 3) % 27))
        end
        diagnosis = @diagnoses[index % @diagnoses.size]
        patient.patient_diagnoses.find_or_create_by!(diagnosis: diagnosis) { |pd| pd.diagnosed_on = @today - 30 - index }
        patient
      end
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
      @regular_count = 0

      plan.each_with_index { |kind, index| create_case(kind, index) }
    end

    # 34 cases: 22 elective regular surgeries, 3 emergencies, 2 joint cases in
    # another department's slot, 2 backup cases, 2 off-slot cath-lab cases,
    # then 3 admissions for examination or chemotherapy without surgery.
    def plan
      Array.new(22, :regular) + Array.new(3, :emergency) + Array.new(2, :simultaneous) + Array.new(2, :backup) +
        Array.new(2, :off_slot) + %i[examination chemotherapy examination]
    end

    def create_case(kind, index)
      patient = @patients.fetch(index)
      marker = "#{MARKER} ##{format('%02d', index + 1)}"
      hospitalization = Hospitalization.find_by(patient: patient, clinical_comment: marker)
      date = case_date(kind, index)
      hospitalization ||= Hospitalization.create!(hospitalization_attributes(kind, index, patient, marker, date))

      return unless surgery_kind?(kind)
      return if hospitalization.surgeries.exists?

      Surgery.create!(surgery_attributes(kind, index, patient, hospitalization, date))
    end

    def surgery_kind?(kind)
      %i[regular emergency simultaneous backup off_slot].include?(kind)
    end

    def case_date(kind, index)
      case kind
      when :emergency then @today + 3 + (index - 22) * 7
      when :examination, :chemotherapy then next_weekday(@today + 4 + (index - 29) * 5)
      else
        # Slot days in order, filling each day's slots before the next round.
        day, total = @surgery_days[@regular_count % @surgery_days.size]
        @slot = (@regular_count / @surgery_days.size) % total + 1
        @regular_count += 1
        day
      end
    end

    def next_weekday(date)
      date += 1 while date.saturday? || date.sunday?
      date
    end

    def hospitalization_attributes(kind, index, patient, marker, date)
      user = @users.values[index % @users.size]
      attrs = {
        patient: patient, clinical_comment: marker, reservation_doctor: user, attending_doctor: user.name,
        reservation_status: Hospitalization::RESERVATION_STATUS_KEYS[index % 4],
        admin_status: (index % 3).zero? ? "confirmed" : "unconfirmed",
        scheduled_admission_date: [ date - ((index % 2).zero? ? 1 : 0), @today ].max,
        submitted_on: @today - (index % 10), planned_days: 3 + index % 6,
        referred_from: (index % 4).zero? ? "近隣クリニック#{%w[A B C][index % 3]}" : nil,
        team: ((index % 9) == 8 && !SiteConfig.current.required_fields(:hospitalization).include?(:team_id)) ? nil : @teams[index % @teams.size],
        hospitalization_diagnoses_attributes: [ { diagnosis_id: @diagnoses[index % @diagnoses.size].id } ]
      }
      attrs.merge!(purpose_attributes(kind, index, date))
      attrs.merge!(transfer_attributes(index))
      attrs[:emergency_admission] = true if kind == :emergency
      attrs
    end

    def purpose_attributes(kind, index, date)
      case kind
      when :examination
        { purpose: "examination", scheduled_procedure_date: date, procedure_name: EXAM_NAMES[index % EXAM_NAMES.size],
          scheduled_admission_date: date }
      when :chemotherapy
        { purpose: "chemotherapy", scheduled_procedure_date: date, procedure_name: "化学療法(第#{index % 4 + 1}コース)",
          scheduled_admission_date: date }
      when :off_slot
        { purpose: "examination", scheduled_procedure_date: date, procedure_name: "心臓カテーテル治療", scheduled_admission_date: date }
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

    def surgery_attributes(kind, index, patient, hospitalization, date)
      procedure = surgery_procedure(kind, index)
      attrs = {
        patient: patient, hospitalization: hospitalization, surgery_date: date,
        anesthesia_method: ANESTHESIA[index % ANESTHESIA.size], duration_hours: [ 1.5, 2.0, 3.0, 4.0, 2.5 ][index % 5],
        operator_name: @users.values[(index + 1) % @users.size].name, assistant_name: @users.values[(index + 2) % @users.size].name,
        scheduling_type: kind == :emergency ? "emergency" : "elective",
        slot_category: %i[simultaneous backup off_slot].include?(kind) ? kind.to_s : "regular",
        surgery_location: @main_room, start_time: format("%02d:00", 9 + index % 4),
        patient_diagnoses: patient.patient_diagnoses.to_a,
        surgery_procedure_selections_attributes: [ { surgery_procedure_id: procedure.id, laterality: "none" } ]
      }
      attrs.merge!(slot_attributes(kind, index))
      attrs[:surgical_device] = @devices[index % @devices.size] if ROBOTIC_PROCEDURES.include?(procedure.name) && @devices.any?
      attrs[:surgery_location] = @hybrid_room if kind == :regular && [ 3, 10, 17 ].include?(index)
      attrs
    end

    def surgery_procedure(kind, index)
      return @procedures.find { |p| p.name == "経皮的冠動脈形成術" } if kind == :off_slot
      return @procedures.find { |p| p.name == ROBOTIC_PROCEDURES[index % 2] } if kind == :regular && (index % 5).zero?

      @procedures[index % (@procedures.size - 3)]
    end

    def slot_attributes(kind, index)
      case kind
      when :regular then { slot_number: @slot, operation_order: @slot }
      when :simultaneous then { department: @partner_department }
      when :backup then { department: @partner_department, backup_intervention: index.even? ? "involved" : "not_involved" }
      when :off_slot then { surgery_location: @cath_lab, performing_department: @departments.third || @partner_department }
      else {}
      end
    end
end
