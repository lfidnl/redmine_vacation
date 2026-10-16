require File.expand_path('../../test_helper', __FILE__)

class VacationMessagesControllerTest < Redmine::ControllerTest
  tests VacationMessagesController

  def setup
    @user  = create_user('vac_owner')
    @other = create_user('vac_intruder')
    Setting.plugin_redmine_vacation = { 'allowed_group_ids' => [] }
    @request.session[:user_id] = @user.id
  end

  def test_index_requires_login
    @request.session[:user_id] = nil
    get :index
    assert_response 302
  end

  def test_index_lists_own_messages_only
    create_message(@user, text: 'Mine')
    create_message(@other, text: 'Not mine')

    get :index
    assert_response :success
    assert_select 'table.vacation-messages td.text', text: /Mine/
    assert_select 'table.vacation-messages td.text', text: /Not mine/, count: 0
  end

  def test_create
    assert_difference 'VacationMessage.count', 1 do
      post :create, params: { vacation_message: {
        date_from: '2026-07-24', date_until: '2026-08-09', text: 'Sommerurlaub',
        color: '#ffebc1', visibility: 'logged', append_dates: '1', show_to_self: '0'
      } }
    end
    assert_redirected_to '/my/vacation_messages'
    message = VacationMessage.last
    assert_equal @user, message.user
    assert_equal '#ffebc1', message.color
  end

  def test_create_ignores_foreign_user_id
    post :create, params: { vacation_message: {
      user_id: @other.id, date_from: '2026-07-24', date_until: '2026-07-24',
      text: 'X', color: '#ffe3e3', visibility: 'logged'
    } }
    assert_equal @user, VacationMessage.last.user
  end

  def test_create_with_errors_renders_form
    assert_no_difference 'VacationMessage.count' do
      post :create, params: { vacation_message: { text: '' } }
    end
    assert_response :success
    assert_select '#errorExplanation'
  end

  def test_update
    message = create_message(@user)
    patch :update, params: { id: message.id, vacation_message: { text: 'Geändert', color: '#dfffdf' } }
    assert_redirected_to '/my/vacation_messages'
    assert_equal 'Geändert', message.reload.text
  end

  def test_cannot_edit_or_delete_foreign_message
    message = create_message(@other)

    get :edit, params: { id: message.id }
    assert_response 404

    assert_no_difference 'VacationMessage.count' do
      delete :destroy, params: { id: message.id }
    end
    assert_response 404
  end

  def test_destroy
    message = create_message(@user)
    assert_difference 'VacationMessage.count', -1 do
      delete :destroy, params: { id: message.id }
    end
    assert_redirected_to '/my/vacation_messages'
  end

  def test_denied_when_not_in_allowed_group
    Setting.plugin_redmine_vacation = { 'allowed_group_ids' => [Group.create!(lastname: 'Only them').id.to_s] }
    get :index
    assert_response 403
  end

  private

  def create_user(login)
    User.create!(login: login, firstname: login, lastname: 'Test',
                 mail: "#{login}@example.com", status: User::STATUS_ACTIVE,
                 password: 'vacation12345', password_confirmation: 'vacation12345')
  end

  def create_message(user, attrs = {})
    VacationMessage.create!({ user: user, date_from: Date.new(2026, 5, 1),
                              date_until: Date.new(2026, 5, 3), text: 'Urlaub',
                              color: '#ffe3e3', visibility: 'logged' }.merge(attrs))
  end
end
