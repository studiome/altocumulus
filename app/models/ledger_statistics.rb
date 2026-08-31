class LedgerStatistics
  def initialize(year: nil)
    @year = year.presence && year.to_i
  end

  def total_patients
    Patient.count
  end

  def current_inpatients_count
    Hospitalization.in_hospital.count
  end

  def surgeries_count
    surgeries_scope.count
  end

  def hospitalizations_count
    hospitalizations_scope.count
  end

  def average_length_of_stay
    lengths = hospitalizations_scope.discharged.filter_map(&:length_of_stay)
    return nil if lengths.empty?

    (lengths.sum.to_f / lengths.size).round(1)
  end

  def monthly_surgery_counts
    monthly_counts(surgeries_scope, :surgery_date)
  end

  def monthly_hospitalization_counts
    monthly_counts(hospitalizations_scope, :admission_date)
  end

  def top_procedures(limit: 10)
    SurgeryProcedureSelection
      .joins(:surgery_procedure)
      .where(surgery_id: surgeries_scope.select(:id))
      .group("surgery_procedures.name")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(limit)
      .count
      .to_a
  end

  def top_diagnoses(limit: 10)
    HospitalizationDiagnosis
      .joins(:diagnosis)
      .where(hospitalization_id: hospitalizations_scope.select(:id))
      .group("diagnoses.name")
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(limit)
      .count
      .to_a
  end

  def anesthesia_breakdown
    surgeries_scope
      .where.not(anesthesia_method: [ nil, "" ])
      .group(:anesthesia_method)
      .order(Arel.sql("COUNT(*) DESC"))
      .count
      .to_a
  end

  def scheduling_type_breakdown
    surgeries_scope
      .group(:scheduling_type)
      .order(Arel.sql("COUNT(*) DESC"))
      .count
      .map { |scheduling_type, count| [ Surgery::SCHEDULING_TYPE_OPTIONS[scheduling_type] || scheduling_type, count ] }
  end

  def outcome_breakdown
    hospitalizations_scope
      .discharged
      .group(:outcome)
      .order(Arel.sql("COUNT(*) DESC"))
      .count
      .map { |outcome, count| [ Hospitalization::OUTCOME_OPTIONS[outcome] || outcome, count ] }
  end

  def available_years
    surgery_years = Surgery.where.not(surgery_date: nil).distinct.pluck(Arel.sql("strftime('%Y', surgery_date)"))
    hospitalization_years = Hospitalization.where.not(admission_date: nil).distinct.pluck(Arel.sql("strftime('%Y', admission_date)"))
    (surgery_years + hospitalization_years).compact.map(&:to_i).uniq.sort.reverse
  end

  private

    def surgeries_scope
      @year ? Surgery.where(surgery_date: year_range) : Surgery.all
    end

    def hospitalizations_scope
      @year ? Hospitalization.where(admission_date: year_range) : Hospitalization.all
    end

    def year_range
      Date.new(@year, 1, 1)..Date.new(@year, 12, 31)
    end

    def target_months
      if @year
        (1..12).map { |month| Date.new(@year, month, 1) }
      else
        end_month = Date.current.beginning_of_month
        11.downto(0).map { |offset| end_month - offset.months }
      end
    end

    def monthly_counts(scope, date_column)
      months = target_months
      window_scope = @year ? scope : scope.where(date_column => months.first..months.last.end_of_month)
      grouped = window_scope.group(Arel.sql("strftime('%Y-%m', #{date_column})")).count

      months.each_with_object({}) do |month, hash|
        hash[Date.new(month.year, month.month, 1)] = grouped[month.strftime("%Y-%m")] || 0
      end
    end
end
