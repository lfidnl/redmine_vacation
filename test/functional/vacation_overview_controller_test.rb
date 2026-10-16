require File.expand_path('../../test_helper', __FILE__)

class VacationOverviewControllerTest < Redmine::ControllerTest
  tests VacationOverviewController

  def setup
    @viewer = create_user('vac_viewer')
    @author = create_user('vac_author')
    @hidden = create_user('vac_hidden')
    Setting.plugin_redmine_vacation = { 'allowed_group_ids' => [] }
    @request.session[:user_id] = @viewer.id
  end

  def test_index_requires_login
    @request.session[:user_id] = nil
    get :index
    assert_response 302
  end

  def test_index_lists_only_visible_absences
    create_message(@author, text: 'Visible', show_banner: false)
    create_message(@hidden, text: 'Secret', visibility: 'selected', principal_ids: [@author.id])

    get :index
    assert_response :success
    assert_select 'table.vacation-overview td.text', text: 'Visible'
    assert_select 'table.vacation-overview td.text', text: 'Secret', count: 0
  end

  def test_project_overview_needs_module_and_permission
    project = Project.create!(name: 'Vacation overview', identifier: 'vacation-overview', is_public: false)
    role = Role.create!(name: 'Vacation viewer', permissions: [:view_project, :view_vacation_overview])
    Member.create!(project: project, user: @viewer, roles: [role])
    Member.create!(project: project, user: @author, roles: [role])
    create_message(@author, text: 'Member')
    create_message(@hidden, text: 'Outsider')

    get :project, params: { project_id: project.identifier }
    assert_response 403

    EnabledModule.create!(project: project, name: 'vacation_messages')
    get :project, params: { project_id: project.identifier }
    assert_response :success
    assert_select 'table.vacation-overview td.text', text: 'Member'
    assert_select 'table.vacation-overview td.text', text: 'Outsider', count: 0
  end

  private

  def create_user(login)
    User.create!(login: login, firstname: login, lastname: 'Test',
                 mail: "#{login}@example.com", status: User::STATUS_ACTIVE,
                 password: 'vacation12345', password_confirmation: 'vacation12345')
  end

  def create_message(user, attrs = {})
    today = User.current.today
    VacationMessage.create!({ user: user, date_from: today, date_until: today + 2,
                              text: 'Urlaub', color: '#ffe3e3', visibility: 'logged' }.merge(attrs))
  end
end
