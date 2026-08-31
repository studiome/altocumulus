class Pagination
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  attr_reader :page, :per_page, :total_count

  def initialize(scope, page:, per_page: DEFAULT_PER_PAGE)
    @scope = scope
    @total_count = scope.count(:all)
    @per_page = clamp_per_page(per_page)
    @page = clamp_page(page)
  end

  def records
    @scope.offset(offset).limit(per_page)
  end

  def total_pages
    (total_count.to_f / per_page).ceil.clamp(1, Float::INFINITY).to_i
  end

  def first_page?
    page <= 1
  end

  def last_page?
    page >= total_pages
  end

  def previous_page
    first_page? ? nil : page - 1
  end

  def next_page
    last_page? ? nil : page + 1
  end

  def offset
    (page - 1) * per_page
  end

  def empty?
    total_count.zero?
  end

  private

    def clamp_per_page(value)
      value.to_i.clamp(1, MAX_PER_PAGE)
    end

    def clamp_page(value)
      value = value.to_i
      value = 1 if value < 1
      value.clamp(1, total_pages)
    end
end
