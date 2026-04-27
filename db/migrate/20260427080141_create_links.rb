class CreateLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :links do |t|
      t.string :url
      t.string :title
      t.text :summary
      t.string :tags
      t.string :status, default: "pending", null: false

      t.timestamps
    end
  end
end
