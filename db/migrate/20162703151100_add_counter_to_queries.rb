class AddCounterToQueries < ActiveRecord::Migration
  def change
    add_column :queries, :eq_counter, :boolean, default: false
  end
end