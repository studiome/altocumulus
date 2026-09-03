require "test_helper"

class PaginationTest < ActiveSupport::TestCase
  test "defaults to page 1 with DEFAULT_PER_PAGE" do
    pagination = Pagination.new(Patient.all, page: nil)

    assert_equal 1, pagination.page
    assert_equal Pagination::DEFAULT_PER_PAGE, pagination.per_page
  end

  test "clamps page below 1 up to 1" do
    pagination = Pagination.new(Patient.all, page: 0)
    assert_equal 1, pagination.page

    pagination = Pagination.new(Patient.all, page: -5)
    assert_equal 1, pagination.page
  end

  test "clamps page above total_pages down to total_pages" do
    pagination = Pagination.new(Patient.all, page: 999, per_page: 1)

    assert_equal Patient.count, pagination.total_pages
    assert_equal pagination.total_pages, pagination.page
  end

  test "handles a non-numeric page gracefully" do
    pagination = Pagination.new(Patient.all, page: "abc")
    assert_equal 1, pagination.page
  end

  test "handles an Array page param gracefully (e.g. ?page[]=1)" do
    pagination = Pagination.new(Patient.all, page: [ "1" ])
    assert_equal 1, pagination.page
  end

  test "handles an Array per_page param gracefully" do
    pagination = Pagination.new(Patient.all, page: 1, per_page: [ "1" ])
    assert_equal Pagination::DEFAULT_PER_PAGE, pagination.per_page
  end

  test "total_count 0 clamps page to 1 and total_pages to 1" do
    pagination = Pagination.new(Patient.where(id: nil), page: 5)

    assert_equal 0, pagination.total_count
    assert_equal 1, pagination.page
    assert_equal 1, pagination.total_pages
    assert pagination.empty?
  end

  test "clamps per_page between 1 and MAX_PER_PAGE" do
    pagination = Pagination.new(Patient.all, page: 1, per_page: 0)
    assert_equal 1, pagination.per_page

    pagination = Pagination.new(Patient.all, page: 1, per_page: 99_999)
    assert_equal Pagination::MAX_PER_PAGE, pagination.per_page
  end

  test "total_pages divides total_count by per_page rounding up" do
    pagination = Pagination.new(Patient.all, page: 1, per_page: 1)
    assert_equal Patient.count, pagination.total_pages
  end

  test "records offsets and limits the scope" do
    pagination = Pagination.new(Patient.order(:hospital_id), page: 2, per_page: 1)

    assert_equal [ patients(:two) ], pagination.records.to_a
    assert_equal 1, pagination.offset
  end

  test "first_page? last_page? previous_page next_page" do
    pagination = Pagination.new(Patient.order(:hospital_id), page: 1, per_page: 1)
    assert pagination.first_page?
    refute pagination.last_page?
    assert_nil pagination.previous_page
    assert_equal 2, pagination.next_page

    pagination = Pagination.new(Patient.order(:hospital_id), page: 2, per_page: 1)
    refute pagination.first_page?
    assert pagination.last_page?
    assert_equal 1, pagination.previous_page
    assert_nil pagination.next_page
  end

  test "total_count is correct for a distinct joined scope" do
    diagnosis = diagnoses(:pneumonia)
    another_diagnosis = diagnoses(:hypertension)
    # hospitalization one has two diagnoses linked (pneumonia + hypertension via
    # fixtures loaded elsewhere); a naive `scope.count(:all)` on a joined,
    # non-distinct relation would double count rows here.
    scope = Hospitalization
      .joins(:hospitalization_diagnoses)
      .where(hospitalization_diagnoses: { diagnosis_id: [ diagnosis.id, another_diagnosis.id ] })
      .distinct

    pagination = Pagination.new(scope, page: 1)

    assert_equal scope.count, pagination.total_count
    assert_equal 1, pagination.total_count
  end
end
