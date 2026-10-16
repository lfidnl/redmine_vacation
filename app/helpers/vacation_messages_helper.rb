module VacationMessagesHelper
  def vacation_period(message)
    if message.single_day?
      format_date(message.date_from)
    else
      "#{format_date(message.date_from)} - #{format_date(message.date_until)}"
    end
  end

  def vacation_visibility_options
    VacationMessage::VISIBILITIES.map { |v| [l("label_vacation_visibility_#{v}"), v] }
  end

  def vacation_visibility_summary(message)
    label = l("label_vacation_visibility_#{message.visibility}")
    case message.visibility
    when 'selected'
      "#{label}: #{message.principals.sort.map(&:name).join(', ')}"
    when 'project_members'
      names = message.projects.sort_by(&:lft).map(&:name).join(', ')
      names += " (#{l(:label_vacation_with_subprojects)})" if message.include_subprojects?
      "#{label}: #{names}"
    else
      label
    end
  end

  # Projects the current user can see, as a tree. Already selected projects
  # stay in the list even if the user lost access to them in between.
  def vacation_project_options(message)
    projects = Project.visible.to_a | message.projects.to_a
    project_tree_options_for_select(projects, selected: message.projects.to_a)
  end

  # Active users and (non built-in) groups, grouped for the recipient select.
  def vacation_recipient_options(message)
    users  = User.active.sorted.where.not(id: User.current.id).to_a
    groups = Group.givable.sorted.to_a
    # Keep already selected principals even if they were locked in between.
    selected = message.principals.to_a
    users  |= selected.grep(User)
    groups |= selected.grep(Group)

    grouped_options_for_select(
      { l(:label_user_plural)  => users.map  { |u| [u.name, u.id] },
        l(:label_group_plural) => groups.map { |g| [g.name, g.id] } },
      message.principal_ids
    )
  end
end
