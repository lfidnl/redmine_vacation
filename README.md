# Vacation Messages for Redmine 7

Every user maintains their own absences under **My account -> Absences**.
While an absence is running, a coloured banner is shown at the top of every
page, e.g.:

> Absence Sven Culley: Summer holiday (24.07.2026 - 09.08.2026)

No gems, no build step. Tested against Redmine 7.0.2 (Rails 8.1, Ruby 4.0);
it also runs on Redmine 6.x.

## Features

- Create, edit and delete your own absences (from / until / text), split
  into "Current & upcoming" and "Past" tabs
- **Substitute**: optional user shown (and linked) next to the absence
- **Visibility** per absence - applies to every place below:
  - everyone (including anonymous visitors)
  - all logged-in users
  - members of projects you share with the author
  - members of selected projects, optionally including their subprojects
    (only projects you can see are offered; archived ones are ignored)
  - selected users and/or groups
- **Banner** on top of every page (optional per absence)
  - colour picker plus presets; border and text colour are derived
  - optional lead time: show the banner X days before the absence starts
  - optionally append the period to the text (lead time and absence)
  - each viewer can hide a banner for the rest of the day (stored in the
    browser; comes back when the absence is edited)
- **Assignee hint**: assigning an issue to someone who is absent, or whose
  absence starts within the next 14 days (configurable), shows a warning
  in the issue form; the issue page shows it for the current assignee
- **Badge** "absent" next to every link to a user who is absent today
  (issue lists, journals, ...); absences are also listed on the user profile
- **Absence overview** in the main menu (`/vacations`) and, with the module
  "Absences" enabled, as a project tab listing the absences of the project
  members (permission "View absence overview")
- **Managers** (admins and configurable groups) maintain absences for
  everyone, e.g. sick leave entered by a team lead
- "Show to myself" - off by default
- Admin settings: who may maintain their own absences, managing groups,
  look-ahead of the assignee hint
- Absences of locked users are hidden

## Installation

```bash
cd /path/to/redmine/plugins
git clone <repo> redmine_vacation      # directory name must match exactly

cd /path/to/redmine
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_vacation
# restart Redmine
```

Uninstall:

```bash
RAILS_ENV=production bundle exec rake redmine:plugins:migrate NAME=redmine_vacation VERSION=0
```

## Where to find it

- Account menu (top right) -> **Absences**
- **My account** -> contextual link **Absences**
- Direct URL: `/my/vacation_messages`
- Overview: main menu **Absence overview** (`/vacations`), project tab after
  enabling the module **Absences**
- Settings: **Administration -> Plugins -> Vacation Messages -> Configure**

Redmine's "My account" page has no tab API, so the plugin brings its own page
instead of patching core views.

## Migrating from the View Customize snippet

Once the plugin is installed, disable the old View Customize entry. Existing
absences can be imported with `rails runner` (adjust login and data):

```ruby
# RAILS_ENV=production bundle exec rails runner import.rb
user = User.find_by!(login: 'sven')
[
  ['2026-07-24', '2026-08-09', 'Sommerurlaub'],
  ['2026-12-14', '2027-01-10', 'Winterurlaub'],
].each do |from, until_, text|
  VacationMessage.create!(user: user, date_from: from, date_until: until_,
                          text: text, color: '#ffe3e3', visibility: 'logged',
                          append_dates: true)
end
```

## Tests

From the Redmine root:

```bash
bundle exec rake redmine:plugins:test NAME=redmine_vacation RAILS_ENV=test
```
