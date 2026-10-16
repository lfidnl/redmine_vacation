require File.expand_path('../../test_helper', __FILE__)

class VacationMessageTest < ActiveSupport::TestCase
  def setup
    @author = create_user('vac_author')
    @viewer = create_user('vac_viewer')
    @other  = create_user('vac_other')
    Setting.plugin_redmine_vacation = { 'allowed_group_ids' => [] }
  end

  def test_validates_date_range
    message = build_message(date_from: Date.new(2026, 5, 10), date_until: Date.new(2026, 5, 1))
    assert_not message.valid?
    assert message.errors[:date_until].any?
  end

  def test_validates_color
    assert_not build_message(color: 'red').valid?
    assert build_message(color: '#AABBCC').valid?
  end

  def test_selected_visibility_requires_recipients
    assert_not build_message(visibility: 'selected').valid?
    assert build_message(visibility: 'selected', principal_ids: [@viewer.id]).valid?
  end

  def test_author_sees_own_message_only_with_show_to_self
    assert_not build_message.visible_to?(@author)
    assert build_message(show_to_self: true).visible_to?(@author)
  end

  def test_visibility_all_and_logged
    assert build_message(visibility: 'all').visible_to?(User.anonymous)
    assert_not build_message(visibility: 'logged').visible_to?(User.anonymous)
    assert build_message(visibility: 'logged').visible_to?(@viewer)
  end

  def test_visibility_selected_users_and_groups
    group = Group.create!(lastname: 'Vacation group')
    group.users << @other

    message = build_message(visibility: 'selected', principal_ids: [@viewer.id, group.id])
    message.save!
    message.reload

    assert message.visible_to?(@viewer)
    assert message.visible_to?(@other)
    assert_not message.visible_to?(create_user('vac_stranger'))
  end

  def test_visibility_shared_projects
    role    = Role.create!(name: 'Vacation role')
    project = Project.create!(name: 'Vacation project', identifier: 'vacation-project')
    Member.create!(project: project, user: @author, roles: [role])
    Member.create!(project: project, user: @viewer, roles: [role])

    message = build_message(visibility: 'projects')
    assert message.visible_to?(@viewer)
    assert_not message.visible_to?(@other)
  end

  def test_displayed_for_only_returns_running_messages
    today = @viewer.today
    running = build_message(date_from: today - 1, date_until: today + 1)
    running.save!
    build_message(date_from: today + 5, date_until: today + 6).save!
    build_message(date_from: today - 6, date_until: today - 5).save!

    assert_equal [running], VacationMessage.displayed_for(@viewer)
  end

  def test_displayed_for_skips_locked_authors
    today = @viewer.today
    build_message(date_from: today, date_until: today).save!
    @author.lock!
    assert_empty VacationMessage.displayed_for(@viewer)
  end

  def test_manageable_by_respects_allowed_groups
    group = Group.create!(lastname: 'Vacation editors')
    group.users << @author
    Setting.plugin_redmine_vacation = { 'allowed_group_ids' => [group.id.to_s] }

    assert VacationMessage.manageable_by?(@author)
    assert_not VacationMessage.manageable_by?(@viewer)
    assert_not VacationMessage.manageable_by?(User.anonymous)
  end

  def test_css_style_picks_readable_text_color
    assert_includes build_message(color: '#ffe3e3').css_style, 'color: #4d4444'
    assert_includes build_message(color: '#003366').css_style, 'color: #ffffff'
  end

  private

  def create_user(login)
    User.create!(login: login, firstname: login, lastname: 'Test',
                 mail: "#{login}@example.com", status: User::STATUS_ACTIVE,
                 password: 'vacation12345', password_confirmation: 'vacation12345')
  end

  def build_message(attrs = {})
    VacationMessage.new({ user: @author, date_from: Date.new(2026, 5, 1),
                          date_until: Date.new(2026, 5, 3), text: 'Urlaub',
                          color: '#ffe3e3', visibility: 'logged' }.merge(attrs))
  end
end
