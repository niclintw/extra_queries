module ExtraQueries
  module QueriesHelperPatch
    def self.included(base)
      base.send(:include, InstanceMethods)

      base.class_eval do
        alias_method_chain :column_value, :eq
      end
    end

    module InstanceMethods
      def column_value_with_eq(column, issue, value)
        if column && column.name == :category && value && @project && Setting.plugin_extra_queries['custom_query_sidebar_enabled']
          link_to(value.name, { controller: :issues, action: :index, project_id: @project, f: [:category_id, :status_id], op: { category_id: '=', status_id: 'o' }, v: { category_id: [value.id] }, set_filter: 1 })
        else
          column_value_without_eq(column, issue, value)
        end
      end
    end
  end
end