require File.expand_path('../../test_helper', __FILE__)

# Dashboard block of the additionals plugin. Skipped when additionals is not
# installed; run it in a Redmine with additionals (PostgreSQL or MySQL).
class VacationDashboardTest < Redmine::IntegrationTest
  def setup
    super
    skip 'additionals is not installed' unless Redmine::Plugin.installed?(:additionals)

    @admin  = create_user('vac_admin', admin: true)
    @author = create_user('vac_author')
    @other  = create_user('vac_other')
    Setting.plugin_redmine_vacation = { 'allowed_group_ids' => [] }

    today = Date.today
    VacationMessage.create!(user: @author, date_from: today, date_until: today + 2,
                            text: 'Sommerurlaub', color: '#ffe3e3', visibility: 'logged')
    VacationMessage.create!(user: @other, date_from: today + 5, date_until: today + 6,
                            text: 'Seminar', color: '#ffe3e3', visibility: 'logged')

    Dashboard.where(dashboard_type: DashboardContentWelcome::TYPE_NAME).delete_all
    @dashboard = Dashboard.create!(name: 'Vacation dashboard', author: @admin,
                                   dashboard_type: DashboardContentWelcome::TYPE_NAME,
                                   system_default: true, visibility: Dashboard::VISIBILITY_PUBLIC)
    @dashboard.layout = { 'left' => ['vacation_messages'] }
    @dashboard.save!
    log_user('vac_admin', 'vacation12345')
  end

  def test_block_is_offered
    assert DashboardContentWelcome.new(user: @admin).available_blocks.key?('vacation_messages')
    assert DashboardContentProject.new(user: @admin).available_blocks.key?('vacation_messages')
  end

  def test_block_lists_everyone_without_selection
    get '/'
    assert_response :success
    assert_select '#block-vacation_messages td.text', text: 'Sommerurlaub'
    assert_select '#block-vacation_messages td.text', text: 'Seminar'
    assert_select '#block-vacation_messages .vacation-user-picker'
  end

  def test_block_settings_select_and_clear_people
    post "/dashboards/#{@dashboard.id}/update_layout_setting",
         params: { settings: { vacation_messages: { user_ids: ['', @other.id.to_s] } } }, xhr: true
    assert_response :success
    assert_equal [@other.id.to_s], @dashboard.reload.layout_settings('vacation_messages')[:user_ids]

    get '/'
    assert_select '#block-vacation_messages td.text', text: 'Seminar'
    assert_select '#block-vacation_messages td.text', text: 'Sommerurlaub', count: 0
    assert_select '#block-vacation_messages .vacation-user-chip', text: /#{@other.name}/

    # Only the empty marker: nobody selected any more, so everyone again.
    post "/dashboards/#{@dashboard.id}/update_layout_setting",
         params: { settings: { vacation_messages: { user_ids: [''] } } }, xhr: true
    assert_equal [], @dashboard.reload.layout_settings('vacation_messages')[:user_ids]
    get '/'
    assert_select '#block-vacation_messages td.text', text: 'Sommerurlaub'
  end

  def test_block_respects_visibility
    VacationMessage.where(user: @author).update_all(visibility: 'selected')
    reset!
    log_user('vac_other', 'vacation12345')
    get '/'
    assert_select '#block-vacation_messages td.text', text: 'Seminar'
    assert_select '#block-vacation_messages td.text', text: 'Sommerurlaub', count: 0
  end

  private

  def create_user(login, admin: false)
    User.create!(login: login, firstname: login, lastname: 'Test', admin: admin,
                 mail: "#{login}@example.com", status: User::STATUS_ACTIVE,
                 password: 'vacation12345', password_confirmation: 'vacation12345')
  end
end
