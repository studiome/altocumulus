# The period (both ends inclusive) in which a fixed set of members serves a
# team, e.g. October-November. Terms of one team never overlap; a clerk enters
# the next term's members once the chief has decided them.
class TeamTerm < ApplicationRecord
  belongs_to :team
  has_many :team_term_members, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :team_term
  accepts_nested_attributes_for :team_term_members,
                                allow_destroy: true,
                                reject_if: ->(attributes) { attributes["name"].blank? && attributes["user_id"].blank? }

  validates :starts_on, :ends_on, presence: true
  validate :ends_on_not_before_starts_on
  validate :must_not_overlap_another_term
  validate :at_most_one_main_and_one_sub

  before_validation :assign_member_positions

  scope :ordered, -> { order(:starts_on) }

  # Members as people read them: main, then sub, then the rest by position.
  def ordered_members
    members = team_term_members.reject(&:marked_for_destruction?)
    members.each_with_index.sort_by { |member, index| [ member.role_rank, member.position || 0, index ] }.map(&:first)
  end

  # e.g. "荒井(M)・原口(S)・園田・斎木"
  def members_display
    ordered_members.map(&:display_label).join(I18n.t("models.team_term.member_separator"))
  end

  def to_s
    "#{starts_on} - #{ends_on}"
  end

  # An unsaved term for the rotation that follows this one: it starts the day
  # after this one ends and lasts as long (whole calendar months stay whole
  # months, so Oct-Nov is followed by Dec-Jan, not by a 61-day span), with the
  # same members and the main and sub roles swapped.
  def build_successor
    next_start = ends_on + 1
    successor = team.team_terms.build(starts_on: next_start, ends_on: successor_end(next_start))
    team_term_members.each do |member|
      successor.team_term_members.build(user_id: member.user_id, name: member.name, role: swapped_role(member.role),
                                        position: member.position)
    end
    successor
  end

  private

    def successor_end(next_start)
      if starts_on.day == 1 && ends_on == ends_on.end_of_month
        months = (ends_on.year * 12 + ends_on.month) - (starts_on.year * 12 + starts_on.month) + 1
        (next_start + months.months - 1.day)
      else
        next_start + (ends_on - starts_on)
      end
    end

    def swapped_role(role)
      { "main" => "sub", "sub" => "main" }.fetch(role, role)
    end

    def ends_on_not_before_starts_on
      return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

      errors.add(:ends_on, :must_be_on_or_after_starts_on)
    end

    def must_not_overlap_another_term
      return if team.nil? || starts_on.blank? || ends_on.blank? || ends_on < starts_on

      others = TeamTerm.where(team_id: team_id).where.not(id: id)
      return unless others.where("starts_on <= ? AND ends_on >= ?", ends_on, starts_on).exists?

      errors.add(:base, :overlaps_another_term)
    end

    def at_most_one_main_and_one_sub
      roles = team_term_members.reject(&:marked_for_destruction?).map(&:role)
      errors.add(:team_term_members, :only_one_main) if roles.count("main") > 1
      errors.add(:team_term_members, :only_one_sub) if roles.count("sub") > 1
    end

    # Rows added after existing ones go to the end, in the order given.
    def assign_member_positions
      live = team_term_members.reject(&:marked_for_destruction?)
      next_position = (live.filter_map { |member| member.position if member.position&.positive? }.max || 0) + 1
      live.each do |member|
        next if member.position&.positive?

        member.position = next_position
        next_position += 1
      end
    end
end
