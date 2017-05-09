class QueryCategory < ActiveRecord::Base
  has_many :query, foreign_key: :category_id, dependent: :nullify
  belongs_to :user, foreign_key: :author_id

  attr_protected :id
end
