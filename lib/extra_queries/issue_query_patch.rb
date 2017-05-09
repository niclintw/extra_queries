module ExtraQueries
  module IssueQueryPatch
    def self.included(base)
      base.send(:include, InstanceMethods)

      base.class_eval do
        attr_reader :eq_reassign
        belongs_to :query_category, foreign_key: :category_id

        has_many :eq_pinned_queries, foreign_key: :query_id

        if Redmine::VERSION.to_s >= '3.0.0'
          has_one :eq_pinned_query, -> { where("#{EqPinnedQuery.table_name}.user_id is null or #{EqPinnedQuery.table_name}.user_id = #{User.current.id}").order("case when #{EqPinnedQuery.table_name}.user_id is null then 0 else #{EqPinnedQuery.table_name}.user_id end") }, class_name: 'EqPinnedQuery', foreign_key: :query_id, dependent: :destroy
          has_one :eq_admin_pinned_query, -> { where("#{EqPinnedQuery.table_name}.user_id is null") }, class_name: 'EqPinnedQuery', foreign_key: :query_id, dependent: :destroy
          has_one :eq_user_pinned_query, -> { where("#{EqPinnedQuery.table_name}.user_id = #{User.current.id}") }, class_name: 'EqPinnedQuery', foreign_key: :query_id, dependent: :destroy
        else
          has_one :eq_pinned_query, class_name: 'EqPinnedQuery', foreign_key: :query_id, conditions: lambda { |*args| "#{EqPinnedQuery.table_name}.user_id is null or #{EqPinnedQuery.table_name}.user_id = #{User.current.id}" }, order: "case when #{EqPinnedQuery.table_name}.user_id is null then 0 else #{EqPinnedQuery.table_name}.user_id end", dependent: :destroy
          has_one :eq_admin_pinned_query, class_name: 'EqPinnedQuery', foreign_key: :query_id, conditions: lambda { |*args| "#{EqPinnedQuery.table_name}.user_id is null" }, dependent: :destroy
          has_one :eq_user_pinned_query, class_name: 'EqPinnedQuery', foreign_key: :query_id, conditions: lambda { |*args| "#{EqPinnedQuery.table_name}.user_id = #{User.current.id}" }, dependent: :destroy
        end
        accepts_nested_attributes_for :eq_admin_pinned_query, :eq_user_pinned_query, allow_destroy: true

        alias_method_chain :build_from_params, :eq
        alias_method_chain :add_available_filter, :eq
        alias_method_chain :initialize_available_filters, :eq
        alias_method_chain :joins_for_order_statement, :eq
        alias_method_chain :available_filters, :eq
        alias_method_chain :sql_for_field, :eq

        scope :eq_sidebar_queries, lambda { |project|
          self.visible
              .includes(:query_category)
              .preload(:eq_pinned_query)
              .preload(:eq_admin_pinned_query)
              .where(project ? ["#{IssueQuery.table_name}.project_id IS NULL OR #{IssueQuery.table_name}.project_id = ?", project.id] : ["#{IssueQuery.table_name}.project_id IS NULL"])
              .where(project ? ["NOT EXISTS(SELECT 1 FROM eq_queries_hide_in_projects eq_hp WHERE eq_hp.query_id = #{IssueQuery.table_name}.id AND eq_hp.project_id = ?)", project.id] : '')
        }
        scope :eq_pinned, -> {
          self.joins("INNER JOIN
                      (
                        SELECT eq.query_id
                        FROM #{EqPinnedQuery.table_name} eq
                        WHERE eq.user_id is null or eq.user_id = #{User.current.id}
                        GROUP BY eq.query_id
                      ) eq_pinned on eq_pinned.query_id = #{IssueQuery.table_name}.id
                     ")
        }

        if Redmine::Plugin.installed?(:ldap_users_sync)
          self.available_columns << QueryColumn.new(:eq_author_branch, sortable: 'eq_adep.name', default_order: 'asc', groupable: 'eq_adep.name')
        end

        self.operators_by_filter_type[:tree_list] = %w(= != ~ !* *)
      end
    end

    module InstanceMethods
      def add_available_filter_with_eq(field, options)
        unless Setting.plugin_extra_queries['custom_query_page_enabled']
          return add_available_filter_without_eq(field, options)
        end

        if %w(author_id assigned_to_id).include?(field)
          values = options[:values] || []

          users = self.eq_locked_users

          options[:values] = values

          if users.size > 0
            options[:values] = options[:values] | ([[l(:eq_dismissed_users), '', { group_title: true }]] + users)
          end
        end

        add_available_filter_without_eq(field, options)
      end

      def all_available_filters
        return @all_available_filters if (@all_available_filters)
        @all_available_filters = self.available_filters
        add_available_filter('project_id', type: :list, values: []) if (@all_available_filters['project_id'].nil?)
        add_available_filter('author_id', type: :list, values: []) if (@all_available_filters['author_id'].nil?)
        add_available_filter('assigned_to_id', type: :list_optional, values: []) if (@all_available_filters['assigned_to_id'].nil?)
        add_available_filter('member_of_group', type: :list_optional, values: []) if (@all_available_filters['member_of_group'].nil?)
        add_available_filter('assigned_to_role', type: :list_optional, values: []) if (@all_available_filters['assigned_to_role'].nil?)
        add_available_filter('fixed_version_id', type: :list_optional, values: []) if (@all_available_filters['fixed_version_id'].nil?)
        add_available_filter('category_id', type: :list_optional, values: []) if (@all_available_filters['category_id'].nil?)
        add_available_filter('is_private', type: :list, values: [[l(:general_text_yes), "1"], [l(:general_text_no), "0"]]) if (@all_available_filters['is_private'].nil?)
        add_available_filter('watcher_id', type: :list, values: [["<< #{l(:label_me)} >>", "me"]]) if (@all_available_filters['watcher_id'].nil?)
        add_available_filter('subproject_id', type: :list_subprojects, values: []) if (@all_available_filters['subproject_id'].nil?)

        Tracker.disabled_core_fields(trackers).each { |field| delete_available_filter(field) }

        @all_available_filters.each do |field, options|
          options[:name] ||= l(options[:label] || "field_#{field}".gsub(/_id$/, ''))
        end
        sort = {}
        @all_available_filters.sort { |(pk, pv), (k, v)| pv[:name] <=> v[:name] }.each do |it|
          sort[it[0]] = it[1]
        end

        return @all_available_filters = sort
      end

      def build_from_params_with_eq(params)
        unless Setting.plugin_extra_queries['custom_query_page_enabled']
          return build_from_params_without_eq(params)
        end

        if params[:saved_query_id].to_i != 0 && self.new_record?
          query = Query.find(params[:saved_query_id].to_i)
          self.attributes = query.attributes.dup
          self.id = query.id
          @new_record = false
          @eq_reassign = true
        end
        res = build_from_params_without_eq(params)

        res.category_id = params[:query][:category_id] if params[:query].present? && params[:query].has_key?(:category_id)

        if params[:sort_criteria] && params[:sort].blank?
          params[:sort] = (params[:sort_criteria].map { |k,v| (v || []).join(':') } || []).join(',')
          res.sort_criteria = params.delete(:sort_criteria) || []
        end

        if res.project.nil?
          res.eq_hide_in_project_ids = params[:query][:hide_in_projects] if params[:query].present? && params[:query].has_key?(:hide_in_projects)
        else
          res.eq_hide_in_project_ids = nil
        end

        res
      end

      def eq_pinned?
        return self.eq_pinned_query.present?
      end

      def eq_admin_pinned?
        return self.eq_admin_pinned_query.present?
      end

      def eq_is_for_all?
        if @is_for_all.nil? && !self.new_record?
          @is_for_all = self.project_id_was.nil? || self.project.nil?
        end
        return @is_for_all
      end


      def initialize_available_filters_with_eq
        initialize_available_filters_without_eq
        unless Setting.plugin_extra_queries['custom_query_page_enabled']
          add_available_filter 'relation_tracker_eq', type: :list, values: trackers.map { |s| [s.name, s.id.to_s] }, label: :eq_label_relation_tracker_filter_caption
        end
      end

      def sql_for_relation_tracker_eq_field(field, operator, value, options={})
        "(EXISTS(SELECT 1
                 FROM #{IssueRelation.table_name} eq_ir
                      INNER JOIN #{Issue.table_name} eq_if on eq_if.id = eq_ir.issue_from_id
                      INNER JOIN #{Issue.table_name} eq_it on eq_it.id = eq_ir.issue_to_id
                 WHERE (eq_ir.issue_from_id = #{Issue.table_name}.id and eq_it.tracker_id #{(operator == '=' ? '' : 'NOT')} in (#{((!value.is_a?(Array) ? [value] : value).map(&:to_i) + [0]).join(',')}))
                    or (eq_ir.issue_to_id = #{Issue.table_name}.id and eq_if.tracker_id #{(operator == '=' ? '' : 'NOT')} in (#{((!value.is_a?(Array) ? [value] : value).map(&:to_i) + [0]).join(',')}))
                 )
         )"
      end

      def available_filters_with_eq
        return @available_filters if @available_filters.present?

        @available_filters = available_filters_without_eq

        if Redmine::Plugin.installed?(:ldap_users_sync)
          vls = UserDepartment.order(:name).map { |it| [it.name, it.id] }
          @available_filters['eq_author_branch'] = { type: :list_optional, values: vls, name: l(:field_eq_author_branch) } if vls.present?
        end

        return @available_filters
      end

      def joins_for_order_statement_with_eq(order_options)
        joins = ''

        if Redmine::Plugin.installed?(:ldap_users_sync) && order_options.present? && order_options.include?('eq_adep.name')
          joins << " LEFT JOIN #{User.table_name} eq_auth on eq_auth.id = #{queried_table_name}.author_id"
          joins << " LEFT JOIN #{UserDepartment.table_name} eq_adep on eq_adep.id = eq_auth.user_department_id"
        end

        joins << ' '
        joins << joins_for_order_statement_without_eq(order_options).to_s
      end

      def sql_for_eq_author_branch_field(field, operator, value)
        return '' unless Redmine::Plugin.installed?(:ldap_users_sync)

        sql = UserDepartment.select("#{UserDepartment.table_name}.id")
                            .joins("INNER JOIN #{User.table_name} a on a.user_department_id = #{UserDepartment.table_name}.id")
                            .where("a.id = #{queried_table_name}.author_id")
        case operator
          when '*', '!*'
            (operator == '*' ? '' : 'NOT ') + "EXISTS(#{sql.to_sql})"
          when '='
            "EXISTS(#{sql.where("#{UserDepartment.table_name}.id in (?)", ((value.is_a?(Array) ? value : [value]).map(&:to_i) + [0])).to_sql})"
          when '!'
            "EXISTS(#{sql.where("#{UserDepartment.table_name}.id not in (?)", ((value.is_a?(Array) ? value : [value]).map(&:to_i) + [0])).to_sql})"
          else
            '1=0'
        end
      end

      def sql_for_field_with_eq(field, operator, value, db_table, db_field, is_custom_filter=false)
        if !is_custom_filter || type_for(field) != :tree_list || operator != '~'
          return sql_for_field_without_eq(field, operator, value, db_table, db_field, is_custom_filter)
        end

        filter = @available_filters[field]
        return nil unless filter

        link_table = filter[:field].format.target_class.table_name

        value = Array.wrap(value)
        items = filter[:field].format.target_class.where(id: value.map(&:to_i) + [0]).to_a
        if items.present?
          conditions = []
          items.each do |it|
            conditions << "tree_cf.lft > #{it.lft} and tree_cf.rgt < #{it.rgt}"
          end
          "#{db_table}.#{db_field} IN (SELECT tree_cf.id FROM #{link_table} tree_cf WHERE (#{conditions.join(') OR (')}))"
        else
          '1=0'
        end
      end
    end
  end
end