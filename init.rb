require 'redmine'
require_relative 'lib/redmine_vacation/hooks'

Redmine::Plugin.register :redmine_vacation do
  name        'Vacation Messages'
  author      'Sven Culley'
  description 'Users maintain their own absences in their account. While an absence ' \
              'is running, a coloured banner is shown on top of every page to the ' \
              'audience the user picked.'
  version     '0.1.0'
  url         'https://github.com/sense-design/redmine_vacation'
  requires_redmine version_or_higher: '6.0.0'

  settings(
    default: {
      'allowed_group_ids' => [] # empty = every logged-in user may maintain absences
    },
    partial: 'settings/redmine_vacation_settings'
  )

  menu :account_menu, :vacation_messages,
       { controller: 'vacation_messages', action: 'index' },
       caption: :label_vacation_messages,
       before:  :my_account,
       if:      proc { VacationMessage.manageable_by?(User.current) }
end
