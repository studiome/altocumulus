class CreateChemotherapyProtocols < ActiveRecord::Migration[8.1]
  # An admin-editable list of treatment protocols (regimens), chosen on the
  # chemotherapy / chemoradiotherapy hospitalizations (see MasterRecord).
  def change
    create_table :chemotherapy_protocols do |t|
      t.string :name, null: false
      t.integer :position, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :chemotherapy_protocols, :name, unique: true

    add_reference :hospitalizations, :chemotherapy_protocol, null: true, foreign_key: true, index: true
  end
end
