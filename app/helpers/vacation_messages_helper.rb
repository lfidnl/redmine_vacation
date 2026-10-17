module VacationMessagesHelper
  def vacation_period(message)
    message.period_text
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

  # Selected recipients as [id, label] for the picker; groups are marked so
  # they can be told apart from users of the same name.
  def vacation_recipient_items(message)
    message.principals.sort.map do |principal|
      [principal.id, principal.is_a?(Group) ? vacation_group_label(principal) : principal.name]
    end
  end

  def vacation_project_items(message)
    message.projects.sort_by(&:lft).map { |project| [project.id, vacation_project_label(project)] }
  end

  # For managers: whose absence is being created.
  def vacation_owner_options(selected)
    options_from_collection_for_select(User.active.sorted, :id, :name, selected&.id)
  end

  def vacation_project_label(project)
    VacationMessage.project_label(project)
  end

  def vacation_group_label(group)
    "#{group.name} (#{l(:label_group)})"
  end
end
