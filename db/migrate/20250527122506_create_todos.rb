class CreateTodos < ActiveRecord::Migration[7.2]
  def change
    create_table :todos do |t|
      t.string :title, null: false, limit: 255
      t.boolean :completed, default: false, null: false

      t.timestamps
    end

    add_index :todos, :completed

    add_index :todos, :created_at
  end
end
