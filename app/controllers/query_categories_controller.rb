class QueryCategoriesController < ApplicationController
  before_filter :require_login
  before_filter :authorized_globaly?
  before_filter :find_query_category, except: [:index, :new, :create, :create_of_query, :move_position]

  def index
    @query_categories = QueryCategory.order(:position)
  end

  def new
    @query_category = QueryCategory.new
    render partial: 'form'
  end

  def edit
    render partial: 'form'
  end

  def update
    @query_category.update_attributes(params[:query_category])
  end

  def create
    @query_category = QueryCategory.create(name: params[:query_category][:name], author_id: User.current.id, position: QueryCategory.order(:position).last.try(:position).to_i + 1)
  end

  def create_of_query
    category = QueryCategory.create(name: params[:name], author_id: User.current.id, position: QueryCategory.order(:position).last.try(:position).to_i + 1)
    render json: { id: category.id, name: category.name }
  end

  def move_position
    qc = QueryCategory.find(params[:query_category_id])
    if params[:new_position].to_i + 1 > qc.position
      QueryCategory.where('position > ? and position <= ?', qc.position, params[:new_position].to_i + 1).update_all('position = position - 1')
    elsif params[:new_position].to_i + 1 < qc.position
      QueryCategory.where('position < ? and position >= ?', qc.position, params[:new_position].to_i + 1).update_all('position = position + 1')
    end
    qc.update_attributes(position: params[:new_position].to_i + 1)

    if request.xhr?
      render nothing: true
      return
    end

    redirect_to action: 'index'
  end

  def destroy
    @query_category.destroy
  end

  private

  def find_query_category
    @query_category = QueryCategory.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

end