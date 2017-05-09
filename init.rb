# rewrite view issues/index.html.erb

Redmine::Plugin.register :extra_queries do
  name 'Extra Queries plugin'
  author 'Kovalevsky Vasil'
  description 'This is a plugin for Redmine'
  version '2.2.7'
  url 'http://rmplus.pro/redmine/plugins/extra_queries'
  author_url 'http://rmplus.pro/'

  project_module :extra_queries do
    permission :eq_manage_query_categories, query_categories: [:index, :new, :create, :update, :edit, :create_of_query, :move_position, :destroy, :find_query_category]
  end

  settings partial: 'extra_queries/settings', default: { 'custom_query_sidebar_enabled' => false, 'custom_query_counter_enabled' => false }

  require 'extra_queries/view_hooks'

  Rails.application.config.to_prepare do
    unless Query.included_modules.include?(ExtraQueries::QueryPatch)
      Query.send(:include, ExtraQueries::QueryPatch)
    end
    unless IssueQuery.included_modules.include?(ExtraQueries::IssueQueryPatch)
      IssueQuery.send(:include, ExtraQueries::IssueQueryPatch)
    end
    unless IssuesController.included_modules.include?(ExtraQueries::IssuesControllerPatch)
      IssuesController.send(:include, ExtraQueries::IssuesControllerPatch)
    end
    unless TimelogController.included_modules.include?(ExtraQueries::TimelogControllerPatch)
      TimelogController.send(:include, ExtraQueries::TimelogControllerPatch)
    end
    unless GanttsController.included_modules.include?(ExtraQueries::GanttsControllerPatch)
      GanttsController.send(:include, ExtraQueries::GanttsControllerPatch)
    end
    unless CalendarsController.included_modules.include?(ExtraQueries::CalendarsControllerPatch)
      CalendarsController.send(:include, ExtraQueries::CalendarsControllerPatch)
    end
    unless QueriesHelper.included_modules.include?(ExtraQueries::QueriesHelperPatch)
      QueriesHelper.send(:include, ExtraQueries::QueriesHelperPatch)
    end
    unless IssuesHelper.included_modules.include?(ExtraQueries::IssuesHelperPatch)
      IssuesHelper.send(:include, ExtraQueries::IssuesHelperPatch)
    end
    unless Issue.included_modules.include?(ExtraQueries::IssuePatch)
      Issue.send(:include, ExtraQueries::IssuePatch)
    end
    unless QueriesController.included_modules.include?(ExtraQueries::QueriesControllerPatch)
      QueriesController.send(:include, ExtraQueries::QueriesControllerPatch)
    end
    unless CustomFieldsController.included_modules.include?(ExtraQueries::CustomFieldsControllerPatch)
      CustomFieldsController.send :include, ExtraQueries::CustomFieldsControllerPatch
    end
    if Redmine::VERSION.to_s >= '3.2.0'
      unless Redmine::FieldFormat::RecordList.included_modules.include?(ExtraQueries::FieldFormatRecordListPatch)
        Redmine::FieldFormat::RecordList.send :include, ExtraQueries::FieldFormatRecordListPatch
      end
    end
    unless Redmine::FieldFormat::UserFormat.included_modules.include?(ExtraQueries::FieldFormatUserPatch)
      Redmine::FieldFormat::UserFormat.send :include, ExtraQueries::FieldFormatUserPatch
    end

    unless User.included_modules.include?(ExtraQueries::UserPatch)
      User.send :include, ExtraQueries::UserPatch
    end
  end

  Rails.application.config.after_initialize do
    plugins = { a_common_libs: '2.1.9' }
    plugin = Redmine::Plugin.find(:extra_queries)
    plugins.each do |k,v|
      begin
        plugin.requires_redmine_plugin(k, v)
      rescue Redmine::PluginNotFound => ex
        raise(Redmine::PluginNotFound, "Plugin requires #{k} not found")
      end
    end
  end
end