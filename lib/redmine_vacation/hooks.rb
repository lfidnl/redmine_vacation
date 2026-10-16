module RedmineVacation
  class Hooks < Redmine::Hook::ViewListener
    # Stylesheet plus the small script that moves the banners to the top of
    # #content and drives the live preview on the form.
    render_on :view_layouts_base_html_head,   partial: 'vacation_messages/html_head'

    # The banners themselves. Core only has a hook at the *end* of #content,
    # so they are rendered there and moved to the top by vacation.js.
    render_on :view_layouts_base_content,     partial: 'vacation_messages/banner'

    # Link in the contextual bar of "My account".
    render_on :view_my_account_contextual,    partial: 'vacation_messages/my_account_link'
  end
end
