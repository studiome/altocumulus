# Inline editing of one day's special slot (特殊枠) lanes on the operations
# calendar: a form in place (a turbo-frame) with a row per active location and
# device master. A number sets that date's SpecialSlotDayOverride (0 = no lane
# that day), blank removes it so the weekly count applies again; a save
# re-renders just that day's tbody. Administrators only, like day notes.
#
# Rows are saved all or nothing: one invalid number re-renders the form with
# every entry kept and the error beside its row.
class DaySpecialSlotsController < ApplicationController
  include CalendarDayRendering

  # One form row: the resource, its override record (new, changed or
  # persisted) and what was typed.
  Row = Struct.new(:resource, :override, :raw) do
    def weekly_default(date)
      resource.special_slot_count_on(date.wday)
    end
  end

  before_action :require_admin
  before_action :set_date
  helper_method :frame_id

  def show
  end

  def edit
    @rows = build_rows
  end

  def update
    @rows = build_rows(entered: entered_counts)
    @rows.each { |row| row.override.valid? if row.raw.present? }

    if @rows.all? { |row| row.raw.blank? || row.override.errors.empty? }
      save_rows
      render_day
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def frame_id
      "day-special-slots-#{@date.iso8601}"
    end

    # {"SurgeryLocation" => {"3" => "2"}, ...}; ids that name nothing on the
    # form are ignored later, types outside the two masters are not permitted.
    def entered_counts
      counts = params[:special_slot_counts]
      return {} unless counts.respond_to?(:permit)

      counts.permit(*SpecialSlotRule::RESOURCE_TYPES.map { |type| { type => {} } }).to_h
    end

    # Active masters (locations first, then devices), plus any inactive one
    # that still has an override on this date so it can be seen and cleared.
    def build_rows(entered: nil)
      existing = SpecialSlotDayOverride.where(date: @date).index_by { |override| [ override.resource_type, override.resource_id ] }
      SpecialSlotRule::RESOURCE_TYPES.flat_map do |type|
        model = type.constantize
        ids_with_override = existing.keys.select { |(existing_type, _)| existing_type == type }.map(&:last)
        model.ordered.includes(:special_slot_rules).where(active: true).or(model.ordered.where(id: ids_with_override)).map do |resource|
          override = existing[[ type, resource.id ]]
          raw = entered ? entered.dig(type, resource.id.to_s).to_s.strip : override&.slot_count.to_s
          override ||= SpecialSlotDayOverride.new(resource: resource, date: @date)
          override.slot_count = raw if entered && raw.present?
          Row.new(resource, override, raw)
        end
      end
    end

    def save_rows
      SpecialSlotDayOverride.transaction do
        @rows.each do |row|
          if row.raw.blank?
            row.override.destroy if row.override.persisted?
          else
            row.override.save!
          end
        end
      end
    end
end
