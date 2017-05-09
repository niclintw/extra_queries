class CreateEqPinnedQueries < ActiveRecord::Migration
  def change
    create_table :eq_pinned_queries do |t|
      t.integer :query_id, null: false
      t.integer :user_id
      t.integer :order
    end

    add_index :eq_pinned_queries, [:query_id], unique: false
    add_index :eq_pinned_queries, [:query_id, :user_id], unique: true
  end
end