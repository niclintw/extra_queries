class ExtraQueriesController < ApplicationController
  before_filter :find_optional_project, only: [:add_filter]

  include IssuesHelper
  helper :issues_extend

  def add_filter
    @fields = params[:fields]

    if params[:query_id].present?
      @query = IssueQuery.find(params[:query_id])
    else
      @query = Query.new_subclass_instance(params[:type] || 'IssueQuery', { project: @project, name: '_' })
    end

    if @project.present?
      @query.project = @project
    end
  end

  def pinning
    @query = IssueQuery.find(params[:query_id])
    if params[:pin]
      @query.eq_user_pinned_query ||= EqPinnedQuery.new(user_id: User.current.id, position: EqPinnedQuery.where(user_id: User.current.id).order("#{EqPinnedQuery.table_name}.position desc").first.try(:position).to_i + 1)
    else
      @query.eq_user_pinned_query.try(:destroy)
    end
  end

  def query_group
    @project = Project.find(params[:project_id]) if params[:project_id]
    if params[:query_group] == 'queries'
      session[:eq_queries_expanded] = params[:status]
    elsif params[:query_group] == 'categories'
      session[:eq_queries_by_category_expanded] = params[:status]
    elsif params[:query_group] == 'queries_by_role'
      session[:eq_queries_by_role_expanded] = params[:status]
    end

    if params[:expand]
      render layout: false
    else
      render nothing: true
    end
  end

  def pinned_queries_order
    queries_ids = params['pinned-query']
    queries = IssueQuery.preload(:eq_user_pinned_query).where(id: queries_ids + [0]).to_a
    queries_ids.each_with_index do |q, index|
      q = queries.select { |it| it.id == q.to_i }.first
      next unless (q)
      q.eq_user_pinned_query ||= EqPinnedQuery.new(user_id: User.current.id)
      q.eq_user_pinned_query.position = index
      q.eq_user_pinned_query.save
    end

    render nothing: true
  end

  private

  def sidebar_queries(query_type)
    @project = Project.find(params[:project_id]) unless params[:project_id].blank?

  end

  def find_optional_project
    @project = Project.find(params[:project_id]) unless params[:project_id].blank?
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end