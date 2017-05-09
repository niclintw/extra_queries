class ChangeQueries < ActiveRecord::Migration
  def self.up
    unless Query.column_names.include?('category_id')
      change_table :queries do |t|
        t.references :category
      end
    end
  end

  def self.down
    remove_column :queries, :category_id
  end
end
