require 'redmine'
require_relative 'lib/redmine_vacation/hooks'

Redmine::Plugin.register :redmine_vacation do
  name        'Vacation Messages'
  author      'Sven Culley'
  description 'Users maintain their own absences in their account. While an absence ' \
              'is running, a coloured banner, a badge next to the name and a hint ' \
              'when assigning issues inform the audience the user picked.'
  version     '0.2.0'
  url         'https://github.com/sense-design/redmine_vacation'
  requires_redmine version_or_higher: '6.0.0'

  settings(
    default: {
      'allowed_group_ids' => [], # empty = every logged-in user may maintain absences
      'manager_group_ids' => [], # may maintain absences for everyone (admins always may)
      'hint_days'         => '14' # how far ahead the assignee hint looks
    },
    partial: 'settings/redmine_vacation_settings'
  )

  project_module :vacation_messages do
    permission :view_vacation_overview, { vacation_overview: [:project] }, read: true
  end

  menu :account_menu, :vacation_messages,
       { controller: 'vacation_messages', action: 'index' },
       caption: :label_vacation_messages,
       before:  :my_account,
       if:      proc { VacationMessage.manageable_by?(User.current) }

  menu :application_menu, :vacation_overview,
       { controller: 'vacation_overview', action: 'index' },
       caption: :label_vacation_overview,
       if:      proc { User.current.logged? }

  menu :project_menu, :vacation_overview,
       { controller: 'vacation_overview', action: 'project' },
       caption: :label_vacation_overview,
       param:   :project_id
end
