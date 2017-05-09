class EqPinnedQuery < ActiveRecord::Base
  belongs_to :issue_query, foreign_key: :query_id
  belongs_to :user

  attr_protected :id
end