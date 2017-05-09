class CreateQueryCategories < ActiveRecord::Migration
  def self.up
    unless ActiveRecord::Base.connection.table_exists?('query_categories')
      create_table :query_categories do |t|
        t.string :name
        t.timestamps
      end
    end
  end

  def self.down
    drop_table :query_categories
  end
end
