RedmineApp::Application.routes.draw do
  scope 'my' do
    resources :vacation_messages, except: [:show]
  end
end
