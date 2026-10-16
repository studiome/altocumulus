# Teams (担当チーム): a department's teams, the terms in which a fixed set of
# members serves a team (members rotate every few months), and the members of
# each term. Hospitalizations and surgeries can be assigned to a team.
class CreateTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :color, null: false, default: "gray"
      t.integer :position, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :teams, :name, unique: true

    create_table :team_terms do |t|
      t.references :team, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.text :note
      t.timestamps
    end
    add_index :team_terms, [ :team_id, :starts_on ]

    create_table :team_term_members do |t|
      t.references :team_term, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :name, null: false
      t.string :role, null: false, default: "member"
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_reference :hospitalizations, :team, foreign_key: true
    add_reference :surgeries, :team, foreign_key: true
  end
end
