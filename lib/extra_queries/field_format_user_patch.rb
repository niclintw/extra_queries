module ExtraQueries
  module FieldFormatUserPatch
    def self.included(base)
      base.send :include, InstanceMethods

      base.class_eval do
        if Redmine::VERSION.to_s >= '3.2.0'
          alias_method_chain :query_filter_values, :eq
        else
          alias_method_chain :query_filter_options, :eq
        end
      end
    end

    module InstanceMethods
      if Redmine::VERSION.to_s >= '3.2.0'
        def query_filter_values_with_eq(custom_field, query)
          if !Setting.plugin_extra_queries['custom_query_page_enabled'] || custom_field.field_format != 'user'
            return query_filter_values_without_eq(custom_field, query)
          end

          if custom_field.format.respond_to?(:ajax_supported) && custom_field.format.ajax_supported && custom_field.ajaxable && query.eq_ajax_like.blank?
            params = query.eq_controller_params || {}
            fields = params[:fields] || params[:f]
            values = params[:values] || params[:v]
            field = "cf_#{custom_field.id}"
            vals = []

            if fields.is_a?(Array) && (values.nil? || values.is_a?(Hash)) && fields.include?(field) && values && values[field]
              vals = Array.wrap(values[field] || []).map(&:to_s)
            end

            return [] if vals.blank?

            eq_user_values(custom_field, query, vals)
          else
            eq_user_values(custom_field, query)
          end
        end
      else
        def query_filter_options_with_eq(custom_field, query)
        if !Setting.plugin_extra_queries['custom_query_page_enabled'] || custom_field.field_format != 'user'
          return query_filter_options_without_eq(custom_field, query)
        end

        { type: :list_optional, values: eq_user_values(custom_field, query) }
        end
      end

      def eq_user_values(custom_field, query, vals=nil)
        if custom_field.user_role.is_a?(Array) && (role_ids = custom_field.user_role.map(&:to_s).reject(&:blank?).map(&:to_i)).any?
          projects_ids = query.eq_project_ids

          users = User.joins(:members).where("#{User.table_name}.status in (?)", [Principal::STATUS_LOCKED, Principal::STATUS_ACTIVE]).where("#{Member.table_name}.project_id in (?)", projects_ids + [0]).order("#{User.table_name}.status").uniq.sorted
          users = users.where("#{Member.table_name}.id IN (SELECT DISTINCT member_id FROM #{MemberRole.table_name} WHERE role_id IN (?))", role_ids)

          if vals.present?
            users = users.where("#{User.table_name}.id in (?)", vals + [0])
          elsif query.eq_ajax_like.present?
            users = users.like(query.eq_ajax_like)
          end

          users_active = []
          users_locked = []

          users.each do |u|
            users_active << [u.name, u.id.to_s] if u.active?
            users_locked << [u.name, u.id.to_s] if u.locked?
          end
        else
          if vals.present?
            users_active = query.eq_active_users_scope.where("#{User.table_name}.id in (?)", vals + [0]).map { |it| [it.name, it.id.to_s] }
            users_locked = query.eq_locked_users_scope.where("#{User.table_name}.id in (?)", vals + [0]).map { |it| [it.name, it.id.to_s] }
          elsif query.eq_ajax_like.present?
            users_active = query.eq_active_users_scope.like(query.eq_ajax_like).map { |it| [it.name, it.id.to_s] }
            users_locked = query.eq_locked_users_scope.like(query.eq_ajax_like).map { |it| [it.name, it.id.to_s] }
          else
            users_active = query.eq_active_users.clone
            users_locked = query.eq_locked_users.clone
          end
        end
        values = users_active

        if users_locked.size > 0
          if values.size > 0
            values += [[l(:eq_dismissed_users), '', { group_title: true }]] + users_locked
          else
            values += users_locked
          end
        end

        values
      end
    end
  end
end