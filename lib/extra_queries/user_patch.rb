module ExtraQueries
  module UserPatch
    def self.included(base)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      def eq_issues_count(view_context=nil, params=nil, session={})
        params ||= {}

        if params[:query_id].to_i > 0
          begin
            query = IssueQuery.find(params[:query_id])
            query.group_by = nil
            query.column_names = nil
            if params[:project_id].present?
              project = Project.find(params[:project_id])
              query.project = project
            end
          rescue ActiveRecord::RecordNotFound
            return 0
          end

          query.issue_ids.size
        else
          0
        end
      end
    end
  end
end