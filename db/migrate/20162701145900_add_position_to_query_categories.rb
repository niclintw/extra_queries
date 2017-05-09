class AddPositionToQueryCategories < ActiveRecord::Migration
  def change
    add_column :query_categories, :position, :integer
    QueryCategory.all.each_with_index do |qc, index|
      qc.update_column :position, index+1
    end
  end
end