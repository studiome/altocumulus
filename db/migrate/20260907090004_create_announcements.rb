class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.boolean :published, null: false, default: true

      t.timestamps
    end
  end
end
