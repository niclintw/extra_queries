module ExtraQueries
  module ExtraQueries
    class Hooks < Redmine::Hook::ViewListener
      render_on(:view_layouts_base_html_head, partial: 'extra_queries/hooks/html_head')
    end
  end
end