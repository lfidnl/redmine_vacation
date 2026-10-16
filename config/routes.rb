RedmineApp::Application.routes.draw do
  scope 'my' do
    resources :vacation_messages, except: [:show] do
      get :autocomplete_users, on: :collection
    end
  end

  get 'vacations', to: 'vacation_overview#index', as: 'vacation_overview'
  get 'projects/:project_id/vacations', to: 'vacation_overview#project',
                                        as: 'project_vacation_overview'
end
