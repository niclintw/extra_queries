class RenameEqPinnedQueriesOrder < ActiveRecord::Migration
  def change
    rename_column :eq_pinned_queries, :order, :position
  end
end