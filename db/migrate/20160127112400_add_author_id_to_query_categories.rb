class AddAuthorIdToQueryCategories < ActiveRecord::Migration
  def change
    add_column :query_categories, :author_id, :integer
  end
end