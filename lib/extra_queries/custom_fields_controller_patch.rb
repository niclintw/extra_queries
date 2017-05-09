module ExtraQueries
  module CustomFieldsControllerPatch
    def self.included(base)
      base.send :include, InstanceMethods

      base.class_eval do
        skip_before_filter :require_admin, only: [:ajax_options]
      end
    end

    module InstanceMethods
      def ajax_options
        cf = CustomField.find(params[:id])
        project = Project.where(id: params[:project_id]).first
        if project && (!project.visible? || !cf.visible_by?(project, User.current))
          render_403
          return
        end
        query = Query.where(id: params[:query_id]).first || IssueQuery.new
        query.eq_ajax_like = params[:q]
        render json: cf.format.send(:query_filter_values, cf, query)
      end
    end
  end
end