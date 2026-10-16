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

  def test_lead_time_banner_follows_append_dates
    today = Date.today
    soon = VacationMessage.create!(user: @deputy, date_from: today + 3, date_until: today + 4,
                                   text: 'Seminar', color: '#dbeafe', visibility: 'logged',
                                   lead_days: 5, append_dates: false)
    get '/my/page'
    assert_select '#vacation-messages .vacation-message', text: /Seminar\s*\z/

    soon.update!(append_dates: true)
    get '/my/page'
    assert_select '#vacation-messages .vacation-message', text: /Seminar \(#{Regexp.escape(soon.period_text)}\)/
  end

  def test_no_banner_before_start_without_lead_time
    VacationMessage.create!(user: @deputy, date_from: Date.today + 1, date_until: Date.today + 2,
                            text: 'Morgen', color: '#dbeafe', visibility: 'logged')
    get '/my/page'
    assert_select '#vacation-messages .vacation-message', text: /Morgen/, count: 0
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

  def test_my_page_block_lists_all_without_selection
    other = VacationMessage.create!(user: @deputy, date_from: Date.today + 10, date_until: Date.today + 12,
                                    text: 'Seminar', color: '#dbeafe', visibility: 'logged')
    add_my_page_block
    get '/my/page'
    assert_select '#block-vacation_messages table.vacation-overview td.text', text: 'Sommerurlaub'
    assert_select '#block-vacation_messages table.vacation-overview td.text', text: other.text
    assert_select '#block-vacation_messages .vacation-user-picker'
  end

  def test_my_page_block_limited_to_selected_people
    VacationMessage.create!(user: @deputy, date_from: Date.today + 10, date_until: Date.today + 12,
                            text: 'Seminar', color: '#dbeafe', visibility: 'logged')
    add_my_page_block
    post '/my/page', params: { settings: { vacation_messages: { user_ids: ['', @deputy.id.to_s] } } }, xhr: true
    assert_response :success

    get '/my/page'
    assert_select '#block-vacation_messages td.text', text: 'Seminar'
    assert_select '#block-vacation_messages td.text', text: 'Sommerurlaub', count: 0
    assert_select '#block-vacation_messages .vacation-user-chip', text: /#{@deputy.name}/

    # Removing everybody again (only the empty marker is sent) shows all.
    post '/my/page', params: { settings: { vacation_messages: { user_ids: [''] } } }, xhr: true
    get '/my/page'
    assert_select '#block-vacation_messages td.text', text: 'Sommerurlaub'
  end

  def test_my_page_block_respects_visibility
    @message.update!(visibility: 'selected', principal_ids: [@deputy.id])
    add_my_page_block
    get '/my/page'
    assert_select '#block-vacation_messages td.text', text: 'Sommerurlaub', count: 0
  end

  def test_welcome_block_is_off_by_default
    get '/'
    assert_select '.vacation-welcome', 0
  end

  def test_welcome_block_all_or_selected
    # With additionals the home page is a dashboard; the hook then only shows
    # inside its "legacy right" block (see vacation_dashboard_test.rb).
    skip 'home page is an additionals dashboard' if Redmine::Plugin.installed?(:additionals)

    VacationMessage.create!(user: @deputy, date_from: Date.today + 10, date_until: Date.today + 12,
                            text: 'Seminar', color: '#dbeafe', visibility: 'logged')
    with_settings plugin_redmine_vacation: { 'allowed_group_ids' => [], 'welcome_enabled' => '1',
                                             'welcome_user_ids' => [] } do
      get '/'
      assert_select '.vacation-welcome td.text', text: 'Sommerurlaub'
      assert_select '.vacation-welcome td.text', text: 'Seminar'
    end
    with_settings plugin_redmine_vacation: { 'allowed_group_ids' => [], 'welcome_enabled' => '1',
                                             'welcome_user_ids' => ['', @deputy.id.to_s] } do
      get '/'
      assert_select '.vacation-welcome td.text', text: 'Seminar'
      assert_select '.vacation-welcome td.text', text: 'Sommerurlaub', count: 0
    end
  end

  private

  def add_my_page_block
    pref = @viewer.pref
    pref.my_page_layout = { 'top' => ['vacation_messages'] }
    pref.save!
  end

  def create_user(login)
    User.create!(login: login, firstname: login, lastname: 'Test',
                 mail: "#{login}@example.com", status: User::STATUS_ACTIVE,
                 password: 'vacation12345', password_confirmation: 'vacation12345')
  end
end
