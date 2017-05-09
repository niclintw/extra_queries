module IssuesExtendHelper
  def eq_query_selected_inline_columns_options_for_mm_page(query)
    (query.mmp_inline_columns & query.available_inline_columns).reject(&:frozen?).collect { |column| [column.caption, column.name] }
  end

  def eq_query_available_inline_columns_options_for_mm_page(query)
    ((query.available_inline_columns - query.mmp_columns).reject(&:frozen?).collect {|column| [column.caption, column.name]}).sort
  end


  def eq_filter_selector(items, options={})
    render(partial: 'extra_queries/filter_selector', locals: { field: options[:field], items: items, options: options })
  end

  def eq_render_filter_field(query, field, options)
    field_selector = field.to_s.gsub('.', '_')

    available_operators = query.eq_available_operator_labels(options[:type]) || []
    operator = (options[:filter] || {})[:operator] || (available_operators.first || [])[1]
    enabled_indexes = operator.present? ? get_enabled_filters(operator) : []

    if Redmine::VERSION.to_s > '3.2.0' && options[:field].present? && !options[:field].is_a?(String) && options[:field].class <= CustomField && options[:field].format.respond_to?(:ajax_supported) && options[:field].format.ajax_supported && options[:field].ajaxable
      ajax_url = url_for({ controller: :custom_fields, action: :ajax_options, id: options[:field].id, query_id: query.try(:id), project_id: @project.try(:id) })
    end

    s = ''
    s << link_to('', '#', id: "f-#{field_selector}", class: "eq-filter-button#{ ' eq-ajaxable' if ajax_url.present?}", title: query.label_for(field), data: { field: field, url: ajax_url })
    s << "<div class='modal_window eq-filter-field' id='modal-f-#{field_selector}' data-field='#{field}'>"
    s << '<div class="eq-filter-operator">'
    s << "#{query.label_for(field)}: "
    s << select_tag("eq-operator-#{field_selector}", options_for_select(available_operators, operator), class: 'eq-operator')
    s << '</div>'
    s << "<div class='eq-filter-data'#{enabled_indexes.any? ? '' : ' style="display: none;"'}>"
    case options[:type].to_s
      when 'list', 'list_optional', 'list_status', 'list_subprojects', 'tree_list'
        s << "<div class='eq-filter-data-list eq-filter-data-item' data-operators='#{get_enabled_filters([0]).join(',')}'>"
        s << eq_filter_selector(options[:values], field: field_selector, name: "eq-values-#{field}[]")
        s << '</div>'
      when 'date', 'date_past'
        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([0]).join(',')}'>"
        s << text_field_tag('eq-values[]', '', size: 10, id: "eq-values-#{field_selector}_1", class: 'value eq-date-value eq-value')
        s << '</span>'

        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([0,1]).join(',')}'>"
        s << ' &mdash; '
        s << text_field_tag('eq-values[]', '', size: 10, id: "eq-values-#{field_selector}_2", class: 'value eq-date-value eq-value')
        s << '</span>'

        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([nil,nil,2]).join(',')}'>"
        s << text_field_tag('eq-values[]', '', size: 3, id: "eq-values-#{field_selector}", class: 'eq-value')
        s << ' '
        s << l(:label_day_plural)
        s << '</span>'
      when 'acl_date_time'
        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([0]).join(',')}'>"
        s << text_field_tag('eq-values[]', '', size: 10, id: "eq-values-#{field_selector}_1", class: 'value eq-periodpicker-value eq-value')
        s << '</span>'
        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([0,1]).join(',')}'>"
        s << ' &mdash; '
        s << text_field_tag('eq-values[]', '', size: 10, id: "eq-values-#{field_selector}_2", class: 'value eq-periodpicker-value eq-value')
        s << '</span>'
      when 'string', 'text'
        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([0]).join(',')}'>"
        s << text_field_tag('eq-values[]', '', size: 30, id: "eq-values-#{field_selector}_1", class: 'eq-value')
        s << '</span>'
      when 'relation'
        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([0]).join(',')}'>"
        s << text_field_tag('eq-values[]', '', size: 6, id: "eq-values-#{field_selector}_1", class: 'eq-value')
        s << '</span>'
        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([nil,1]).join(',')}'>"
        s << select_tag('eq-values[]', options_for_select(query.all_projects_values, nil), id: "eq-values-#{field_selector}_2", class: 'eq-value')
        s << '</span>'
      when 'integer', 'float', 'tree', 'sd_time'
        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([0]).join(',')}'>"
        s << text_field_tag('eq-values[]', '', size: 6, id: "eq-values-#{field_selector}_1", class: 'eq-value')
        s << '</span>'
        s << "<span class='eq-filter-data-item' data-operators='#{get_enabled_filters([0,1]).join(',')}'>"
        s << ' &mdash; '
        s << text_field_tag('eq-values[]', '', size: 6, id: "eq-values-#{field_selector}_2", class: 'eq-value')
        s << '</span>'
    end
    s << '</div>'
    s << '</div>'
    s.html_safe
  end

  def get_enabled_filters(operator)
    case operator
      when '><' then [0,1]
      when '<t+', '>t+', '><t+', 't+', '>t-', '<t-', '><t-', 't-', 'tm=', 'tw=' then [nil,nil,2]
      when '=p', '=!p', '!p' then [nil,1]
      when '!*', '*', 't', 'ld', 'w', 'lw', 'l2w', 'm', 'lm', 'y', 'o', 'c' then []
      when [0,1] then ['><']
      when [nil,nil,2] then ['<t+', '>t+', '><t+', 't+', '>t-', '<t-', '><t-', 't-', 'tm=', 'tw=']
      when [nil,1] then ['=p', '=!p', '!p']
      when [0] then ['=', '!', '>=', '<=', '~', '!~', '><', 't><', 't>', 't<']
      when [] then ['!*', '*', 't', 'ld', 'w', 'lw', 'l2w', 'm', 'lm', 'y', 'o', 'c']
    else [0]
    end
  end



  def eq_sidebar_url_params
    @eq_sidebar_url_params ||= case when params[:type] == 'gantts' then { controller: :gantts, action: :show }
                                    when params[:type] == 'calendars' then { controller: :calendars, action: :show }
                                    when params[:type] == 'cp_burndown' then { controller: :cp_burndown, action: :index }
                                    when controller.controller_name == 'issues' && controller.action_name != 'index' then { controller: :issues, action: :index }
                                    when params[:type].blank? then {}
                               else { controller: :issues, action: :index }
                               end
  end

  def eq_render_sidebar_pinned_queries
    queries = IssueQuery.eq_sidebar_queries(@project)
                        .eq_pinned
                        .preload(:eq_admin_pinned_query)
                        .joins("LEFT JOIN #{EqPinnedQuery.table_name} eq on eq.query_id = #{IssueQuery.table_name}.id and eq.user_id = #{User.current.id}")
                        .order("eq.position, #{IssueQuery.table_name}.name")
                        .to_a

    return '' if (queries == [])
    html = ''

    html << '<ul>'
    queries.each do |query|
      html << "<li id='pinned-query-#{query.id}'>"
      html << link_to("<span>#{h(query.name)}</span>".html_safe, eq_sidebar_url_params.merge({ project_id: @project, query_id: query.id }), class: @query.try(:id) == query.id ? 'no_line selected' : nil)

      if Redmine::Plugin.installed?(:ajax_counters) && Setting.plugin_extra_queries['custom_query_counter_enabled'] && query.eq_counter
        html << User.current.ajax_counter('eq_issues_count', { period: 300, css: 'count ac_light', params: { query_id: query.id, project_id: @project.try(:id) }}).html_safe
      end
      unless query.eq_admin_pinned?
        html << link_to('&nbsp;'.html_safe, { controller: :extra_queries, action: :pinning, query_id: query.id }, remote: true, method: :post, class: 'eq-pinning eq-unpin', title: l(:eq_title_unpin_query))
      end
      html << '</li>'
    end
    html << '</ul>'
    html.html_safe
  end

  def eq_render_sidebar_queries
    queries = IssueQuery.eq_sidebar_queries(@project).order("#{QueryCategory.table_name}.position, #{IssueQuery.table_name}.name").to_a
    return '' if (queries == [])

    html = ''
    cat_name = '~!~'

    queries.each do |query|
      if query.query_category.try(:name) != cat_name
        html << '</ul>' if cat_name != '~!~'
        if query.query_category.try(:name).present?
          html << content_tag('h4', h(query.query_category.name))
        end
        html << '<ul>'

        cat_name = query.query_category.try(:name).to_s
      end
      html << "<li id='query-#{query.id}'>"
      html << link_to("<span>#{h(query.name)}</span>".html_safe, eq_sidebar_url_params.merge({ project_id: @project, query_id: query.id }), class: @query.try(:id) == query.id ? 'no_line selected' : nil)
      if Redmine::Plugin.installed?(:ajax_counters) && Setting.plugin_extra_queries['custom_query_counter_enabled'] && query.eq_counter
        html << User.current.ajax_counter('eq_issues_count', { period: 300, css: 'count ac_light', params: { query_id: query.id, project_id: @project.try(:id) }}).html_safe
      end
      unless query.eq_admin_pinned?
        html << link_to('&nbsp;'.html_safe, { controller: :extra_queries, action: :pinning, query_id: query.id, pin: query.eq_pinned? ? nil : 1 }, remote: true, method: :post, class: 'show_loader eq-pinning ' + (query.eq_pinned? ? 'eq-unpin' : 'eq-pin'), title: query.eq_pinned? ? l(:eq_title_unpin_query) : l(:eq_title_pin_query))
      end
      html << '</li>'
    end

    html << '</ul>'
    html = '<div>' + html + '</div>'
    html.html_safe
  end

  def eq_render_categories_links
    scope = IssueCategory.joins({ issues: :status })
                         .where("#{IssueStatus.table_name}.is_closed = ?", false)
                         .group(IssueCategory.table_name + '.' + IssueCategory.column_names.join(", #{IssueCategory.table_name}."))
                         .order("#{IssueCategory.table_name}.name")
    scope = scope.where(project_id: @project.id) if (@project)

    html = ''
    if scope != []
      html << '<ul id="eq-sidebar-issue-categories">'
      scope.each do |ic|
        html << '<li>'
        html << link_to(ic.name, eq_sidebar_url_params.merge({ project_id: @project, f: [:category_id, :status_id], op: { category_id: '=', status_id: 'o' }, v: { category_id: [ic.id] }, set_filter: 1 }))
        html << '</li>'
      end
      html << '</ul>'

      html = '<div>' + html + '</div>'
    end
    html.html_safe
  end

  def eq_render_queries_by_role_links(project)
    return '' unless project

    specific_roles = Setting.plugin_extra_queries['specific_roles'].nil? ? [] : Setting.plugin_extra_queries['specific_roles']
    custom_rule = Setting.plugin_extra_queries['custom_rule']

    roles = Role.joins({ members: :user })
                .where("#{Member.table_name}.project_id = ?
                    and #{User.table_name}.status = ?
                       ", project.id, User::STATUS_ACTIVE)
                .order("#{Role.table_name}.name")
                .order(*User.fields_for_order_statement)
                .select("#{Role.table_name}.name,
                         #{Role.table_name}.builtin,
                         #{Role.table_name}.id,
                         #{User.table_name}.id as user_id,
                         CONCAT(#{User.table_name}." + (User.name_formatter[:order] - ['id', 'login', 'status', 'mail']).join(", ' ', #{User.table_name}.") + ") as user_name
                        ")
                .group("#{Role.table_name}.name, #{Role.table_name}.builtin, #{Role.table_name}.id, #{User.table_name}.id, #{User.fields_for_order_statement.join(', ')}")

    return '' if roles.blank?
    role_id = nil
    html = ''
    roles.each do |role|
      if role_id != role.id
        html << '</ul></li></ul>' if role_id.present?
        html << '<ul>'
        html << '<li>'
        html << role.name
        html << '<ul>'

        role_id = role.id
      end
      html << '<li>'
      custom_filter = specific_roles.include?(role.id.to_s) ? custom_rule.to_sym : :assigned_to_id
      html << link_to(role.attributes['user_name'], eq_sidebar_url_params.merge({ project_id: @project, group_by: 'status', f: [:status_id, custom_filter], op: { status_id: 'o', custom_filter => '=' }, v: { custom_filter => [role.attributes['user_id']] }, set_filter: 1 }))
      html << '</li>'
    end
    html << '</ul></li></ul>'

    html = '<div>' + html + '</div>'
    html.html_safe
  end


  def eq_redirect_to_issues_path(options)
    if params[:cp_burndown] && Redmine::Plugin.installed?(:clear_plan)
      if @project
        url_for({ controller: :cp_burndown, action: :index, project_id: @project }.merge(options))
      else
        url_for({ controller: :cp_burndown, action: :index }.merge(options))
      end
    elsif params[:gantt]
      if @project
        project_gantt_path(@project, options)
      else
        issues_gantt_path(options)
      end
    else
      _project_issues_path(@project, options)
    end
  end
end