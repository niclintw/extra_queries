class CreateEqQueriesHideInProjects < ActiveRecord::Migration
  def change
    create_table :eq_queries_hide_in_projects, id: false do |t|
      t.integer :query_id, null: false
      t.integer :project_id, null: false
    end

    add_index :eq_queries_hide_in_projects, [:query_id, :project_id], unique: true
    add_index :eq_queries_hide_in_projects, [:query_id]
    add_index :eq_queries_hide_in_projects, [:project_id]
  end
end