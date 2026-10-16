require File.expand_path('../../test_helper', __FILE__)

class VacationHooksTest < Redmine::IntegrationTest
  def setup
    super
    @viewer = create_user('vac_viewer')
    @author = create_user('vac_author')
    @deputy = create_user('vac_deputy')
    Setting.plugin_redmine_vacation = { 'allowed_group_ids' => [] }

    @status   = IssueStatus.create!(name: 'Vacation new')
    @tracker  = Tracker.create!(name: 'Vacation tracker', default_status: @status)
    @priority = IssuePriority.create!(name: 'Vacation normal', is_default: true)
    @project  = Project.create!(name: 'Vacation hooks', identifier: 'vacation-hooks')
    @project.trackers << @tracker unless @project.trackers.include?(@tracker)
    role = Role.create!(name: 'Vacation dev', assignable: true,
                        permissions: [:view_project, :view_issues, :add_issues, :edit_issues])
    Member.create!(project: @project, user: @viewer, roles: [role])
    Member.create!(project: @project, user: @author, roles: [role])

    @issue = Issue.create!(project: @project, tracker: @tracker, status: @status,
                           priority: @priority, subject: 'Vacation issue',
                           author: @viewer, assigned_to: @author)

    today = Date.today
    @message = VacationMessage.create!(user: @author, date_from: today - 1, date_until: today + 1,
                                       text: 'Sommerurlaub', color: '#ffe3e3',
                                       visibility: 'logged', substitute: @deputy)
    log_user('vac_viewer', 'vacation12345')
  end

  def test_banner_with_substitute_and_dismiss_button
    get '/my/page'
    assert_select '#vacation-messages .vacation-message', text: /Sommerurlaub/ do
      assert_select 'a.user', text: @deputy.name
      assert_select 'button.vacation-dismiss'
    end
  end

  def test_no_banner_when_disabled
    @message.update!(show_banner: false)
    get '/my/page'
    assert_select '#vacation-messages', 0
    # ...but the badge data is still there
    assert_select 'script#vacation-absent-users', text: /Sommerurlaub/
  end

  def test_issue_page_warns_about_absent_assignee
    get "/issues/#{@issue.id}"
    assert_response :success
    assert_select '.vacation-assignee-hint', text: /Sommerurlaub/
  end

  def test_issue_form_carries_assignee_hints
    get "/projects/#{@project.identifier}/issues/new"
    assert_response :success
    assert_select ".vacation-assignee-hint[data-hints*='#{@author.id}']"
  end

  def test_profile_lists_absences
    get "/users/#{@author.id}"
    assert_response :success
    assert_select '.vacation-profile li', text: /Sommerurlaub/
  end

  def test_invisible_absence_leaves_no_trace
    @message.update!(visibility: 'selected', principal_ids: [@deputy.id])
    get "/issues/#{@issue.id}"
    assert_select '.vacation-assignee-hint', 0
    assert_select 'script#vacation-absent-users', 0
    assert_select '#vacation-messages', 0
  end

  private

  def create_user(login)
    User.create!(login: login, firstname: login, lastname: 'Test',
                 mail: "#{login}@example.com", status: User::STATUS_ACTIVE,
                 password: 'vacation12345', password_confirmation: 'vacation12345')
  end
end
