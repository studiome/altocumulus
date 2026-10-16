# "Team undecided" is a deliberate answer, distinct from leaving the team blank
# (not chosen yet): the case is waiting for a team assignment. Hospitalizations
# and surgeries both carry it, like team_id.
class AddTeamUndecided < ActiveRecord::Migration[8.1]
  def change
    add_column :hospitalizations, :team_undecided, :boolean, null: false, default: false
    add_column :surgeries, :team_undecided, :boolean, null: false, default: false
  end
end
