get 'projects/:project_id/extra_queries/add_filter(/:query_id)', to: 'extra_queries#add_filter'

resources :query_categories do
  collection do
    post 'create_of_query', to: 'query_categories#create_of_query'
    post 'move_position', to: 'query_categories#move_position'
  end
end

get 'extra_queries/add_filter(/:query_id)', to: 'extra_queries#add_filter'
post 'extra_queries/pinning/:query_id', to: 'extra_queries#pinning'
get 'extra_queries/query_group/:query_group(/:project_id)', to: 'extra_queries#query_group'
post 'extra_queries/pinned_queries_order', to: 'extra_queries#pinned_queries_order'
resources :custom_fields do
  member do
    get 'ajax_options'
  end
end