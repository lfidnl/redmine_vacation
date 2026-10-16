module RedmineVacation
  class Hooks < Redmine::Hook::ViewListener
    # Stylesheet, script and the list of users absent today (for the badges).
    render_on :view_layouts_base_html_head,     partial: 'vacation_messages/html_head'

    # The banners themselves. Core only has a hook at the *end* of #content,
    # so they are rendered there and moved to the top by vacation.js.
    render_on :view_layouts_base_content,       partial: 'vacation_messages/banner'

    # Link in the contextual bar of "My account".
    render_on :view_my_account_contextual,      partial: 'vacation_messages/my_account_link'

    # Warn when assigning an issue to someone who is (about to be) absent.
    render_on :view_issues_form_details_bottom, partial: 'vacation_messages/assignee_hint_form'
    render_on :view_issues_show_details_bottom, partial: 'vacation_messages/assignee_hint_show'

    # Optional block on the home page (plugin setting).
    render_on :view_welcome_index_right,        partial: 'vacation_messages/welcome'

    # Absences on the user's profile page.
    render_on :view_account_left_bottom,        partial: 'vacation_messages/user_profile'
  end
end
