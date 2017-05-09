module ExtraQueries
  module IssuesHelperPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        include IssuesExtendHelper

        alias_method_chain :render_sidebar_queries, :eq
        alias_method_chain :sidebar_queries, :eq
      end
    end

    module InstanceMethods
      def sidebar_queries_with_eq
        unless @sidebar_queries
          @sidebar_queries = IssueQuery.visible
                                       .order("#{Query.table_name}.name ASC")
                                       .where(@project.nil? ? ["project_id IS NULL"] : ["project_id IS NULL OR project_id = ?", @project.id])
                                       .where(@project.nil? ? "" : ["NOT EXISTS(SELECT 1 FROM eq_queries_hide_in_projects eq_hp WHERE eq_hp.query_id = #{Query.table_name}.id AND eq_hp.project_id = ?)", @project.id])
                                       .to_a
        end
        @sidebar_queries
      end

      def render_sidebar_queries_with_eq
        if Setting.plugin_extra_queries['custom_query_sidebar_enabled']
          out = ''
          q = eq_render_sidebar_pinned_queries
          out << '<br>'
          out << "<div id='eq-sidebar-pinned-queries' class='eq-sidebar-queries' style='#{q.blank? ? 'display: none;' : ''}' data-url='#{url_for({ controller: :extra_queries, action: :pinned_queries_order, type: params[:controller] })}'>"
          out << q
          out << '</div>'

          if Redmine::Plugin.installed?(:global_roles) && User.current.global_permission_to?(:eq_manage_query_categories)
            out << "<span>#{link_to l(:eq_manage_query_categories), {controller: 'query_categories', action: 'index'}}</span>"
          end

          out << "<fieldset class='eq-sidebar-queries eq-sidebar-taggable-fieldset#{session[:eq_queries_expanded] ? ' expanded' : ''}'>"
          out << '<legend>'
          out << '<span>'
          out << '<i class="fa fa-refresh fa-spin"></i>'
          out << link_to(l(:label_query_plural), { controller: :extra_queries, action: :query_group, query_group: 'queries', project_id: @project.try(:identifier), type: params[:controller] }, class: 'in_link')
          out << '</span>'
          out << '</legend>'
          out << eq_render_sidebar_queries if session[:eq_queries_expanded]
          out << '</fieldset>'

          if @project
            cat = eq_render_categories_links
            if cat.present?
              out << "<fieldset class='eq-sidebar-queries eq-sidebar-taggable-fieldset#{session[:eq_queries_by_category_expanded] ? ' expanded' : ''}'>"
              out << '<legend>'
              out << '<span>'
              out << '<i class="fa fa-refresh fa-spin"></i>'
              out << link_to(l(:eq_label_categories), { controller: :extra_queries, action: :query_group, query_group: 'categories', project_id: @project.identifier, type: params[:controller] }, class: 'in_link')
              out << '</span>'
              out << '</legend>'
              out << cat if session[:eq_queries_by_category_expanded]
              out << '</fieldset>'
            end
          end

          out.html_safe
        else
          render_sidebar_queries_without_eq
        end
      end
    end
  end
end