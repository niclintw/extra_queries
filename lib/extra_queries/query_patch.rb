module ExtraQueries
  module QueryPatch
    def self.included(base)
      base.send :include, InstanceMethods

      base.class_eval do
        include Redmine::SubclassFactory

        attr_accessor :eq_editable_by_was
        alias_method_chain :editable_by?, :eq

        has_and_belongs_to_many :eq_hide_in_projects, class_name: 'Project', join_table: "#{table_name_prefix}eq_queries_hide_in_projects#{table_name_suffix}", foreign_key: 'query_id'

        attr_accessor :eq_ajax_like
        attr_accessor :eq_controller_params

        alias_method_chain :build_from_params, :extra_queries
      end
    end

    module InstanceMethods
      def build_from_params_with_extra_queries(params)
        self.eq_controller_params = params
        build_from_params_without_extra_queries(params)
      end

      def editable_by_with_eq?(user)
        return editable_by_without_eq?(user) if self.new_record? || self.eq_editable_by_was

        q = Query.where(id: self.id).first
        return editable_by_without_eq?(user) if q.blank?
        q.eq_editable_by_was = true
        q.editable_by?(user)
      end

      def eq_project_ids
        return @eq_project_ids if @eq_project_ids
        @eq_project_ids = []
        if self.project
          @eq_project_ids << self.project.id

          unless self.project.leaf?
            @eq_project_ids += self.project.descendants.visible.map(&:id)
          end
        else
          if self.all_projects.any?
            @eq_project_ids = self.all_projects.map(&:id)
          end
        end

        @eq_project_ids
      end

      def eq_active_users_scope
        User.joins(:members).active.where("#{Member.table_name}.project_id in (?)", self.eq_project_ids + [0]).uniq.sorted
      end

      def eq_active_users
        return @eq_active_users if @eq_active_users.present?

        @eq_active_users = self.eq_active_users_scope
        @eq_active_users = @eq_active_users.map { |s| [s.name, s.id.to_s] }
      end

      def eq_locked_users_scope
        User.joins(:members).where("#{User.table_name}.status = ?", Principal::STATUS_LOCKED).where("#{Member.table_name}.project_id in (?)", self.eq_project_ids + [0]).uniq.sorted
      end

      def eq_locked_users
        return @eq_locked_users if @eq_locked_users.present?

        @eq_locked_users = self.eq_locked_users_scope
        @eq_locked_users = @eq_locked_users.map { |s| [s.name, s.id.to_s] }
      end

      def eq_filters
        return @eq_filters if (@eq_filters)

        filter_fields = self.is_a?(IssueQuery) ? (Setting.plugin_extra_queries['default_filter_fields'] || []) : []
        filter_fields = self.available_filters.select { |field, options| filter_fields.include?(field.to_s) }
        filter_fields ||= { }
        sort = { }
        # let s sort default filters
        filter_fields.sort { |(pk, pv), (k, v)| pv[:name] <=> v[:name] }.each do |it|
          sort[it[0]] = it[1]
        end
        filter_fields = sort

        # no sort, just like was added by user
        self.filters.each do |field, options|
          if (v = self.available_filters[field])
            filter_fields[field] = v.merge({ filter: options, user: filter_fields[field].nil? })
            if filter_fields[field][:type] == :relation
              filter_fields[field] = filter_fields[field].merge({ values: self.all_projects_values })
            end
          end
        end
        @eq_filters = filter_fields
      end

      def eq_available_operator_labels(type)
        available_operators = Query.operators_by_filter_type[type]
        if available_operators.present?
          available_operators = available_operators.inject([]) { |res, it| res << [l(*Query.operators[it.to_s]), it.to_s] if Query.operators[it.to_s].present?; res }
        end
        available_operators
      end

      def eq_to_params
        res = {}

        (self.filters || {}).each do |k, f|
          res[:f] ||= []
          res[:f] << k
          res[:op] = { k => f[:operator] }

          f[:values] = [f[:values]] if (f[:values].present? || f[:values] == '') && !f[:values].is_a?(Array)

          res[:v] = { k => f[:values] }
        end

        (self.sort_criteria || []).each do |sort|
          res[:sort_criteria] ||= []
          res[:sort_criteria] << sort
        end

        res[:group_by] = self.group_by if self.group_by.present?

        res[:c] = self.column_names if self.column_names.present?

        res
      end

      def hide_in_projects
        self.eq_hide_in_project_ids
      end

      def hide_in_projects=(v)
        self.eq_hide_in_project_ids = v
      end
    end
  end
end