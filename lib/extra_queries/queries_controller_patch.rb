module ExtraQueries
  module QueriesControllerPatch
    def self.included(base)
      base.send(:include, InstanceMethods)
      base.class_eval do
        helper :issues_extend

        alias_method_chain :create, :eq
        alias_method_chain :update, :eq
        alias_method_chain :edit, :eq
        alias_method_chain :redirect_to_issues, :eq
        if Redmine::VERSION.to_s >= '3.0.0'
          alias_method_chain :update_query_from_params, :eq
        end

        before_filter :qe_query_view, only: [:new, :edit, :create, :update]
        layout :eq_query_layout, only: [:new, :edit]
      end
    end

    module InstanceMethods
      def create_with_eq
        if Setting.plugin_extra_queries['custom_query_sidebar_enabled']
          if params[:query] && params[:query].delete(:eq_pinned) && User.current.admin?
            params[:query][:eq_admin_pinned_query_attributes] = { user_id: nil }
          end

          params[:query][:eq_user_pinned_query_attributes] = { user_id: User.current.id }
        end
        create_without_eq
      end

      def update_with_eq

        if Setting.plugin_extra_queries['custom_query_sidebar_enabled'] && User.current.admin?
          if params[:query] && params[:query].delete(:eq_pinned)
            @query.eq_admin_pinned_query ||= EqPinnedQuery.new(user_id: nil)
          else
            @query.eq_admin_pinned_query.try(:destroy)
          end
        end

        update_without_eq
      end

      def update_query_from_params_with_eq
        update_query_from_params_without_eq
        if params[:query] && params[:query][:eq_counter]
          @query.eq_counter = params[:query][:eq_counter]
        end
        @query
      end

      def edit_with_eq
        if params[:gantt].blank? && Setting.plugin_extra_queries['custom_query_page_enabled']
          if Redmine::Plugin.installed?(:magic_my_page)
            params[:mmp_column_names] = @query.mmp_column_names
          end
          @query.build_from_params(params)
        end
        edit_without_eq
      end

      def redirect_to_issues_with_eq(options)
        if params[:gantt].blank? && Setting.plugin_extra_queries['custom_query_page_enabled'] && request.xhr?
          render action: 'new'
        else
          redirect_to_issues_without_eq(options)
        end
      end

      def eq_query_layout
        return 'base' if params[:gantt].present? || !request.xhr?
        Setting.plugin_extra_queries['custom_query_page_enabled'] ? false : 'base'
      end

      def qe_query_view
        if request.xhr? && params[:gantt].blank? && Setting.plugin_extra_queries['custom_query_page_enabled']
          prepend_view_path File.join(Redmine::Plugin.find(:extra_queries).directory, 'app', 'views', 'extra_queries')
        end
      end
    end
  end
end