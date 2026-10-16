# Vacation Messages for Redmine 7

Every user maintains their own absences under **My account -> Absences**.
While an absence is running, a coloured banner is shown at the top of every
page, e.g.:

> Absence Sven Culley: Summer holiday (24.07.2026 - 09.08.2026)

No gems, no build step. Tested against Redmine 7.0.2 (Rails 8.1, Ruby 4.0);
it also runs on Redmine 6.x.

## Features

- Create, edit and delete your own absences (from / until / text)
- Colour per absence: colour picker plus presets (red, yellow, green, blue,
  grey); border and text colour are derived automatically
- Optionally append the period to the text automatically
- Visibility per absence:
  - everyone (including anonymous visitors)
  - all logged-in users
  - members of projects you share with the author
  - members of selected projects, optionally including their subprojects
    (only projects you can see are offered; archived ones are ignored)
  - selected users and/or groups
- "Show to myself" - off by default, so you do not see your own banner
- Tabs "Current & upcoming" / "Past"
- Admin setting: which groups may maintain absences (empty = everyone)
- Banners of locked users are hidden

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
