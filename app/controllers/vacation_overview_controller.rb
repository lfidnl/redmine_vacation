class VacationOverviewController < ApplicationController
  menu_item :vacation_overview

  before_action :require_login, only: [:index, :autocomplete_users]
  before_action :find_project_by_project_id, :authorize, only: [:project]

  # All current and upcoming absences the user may see.
  def index
    @messages = VacationMessage.listed_for(User.current)
    render :index
  end

  # Absences of the members of a project and its subprojects.
  def project
    project_ids = @project.self_and_descendants.pluck(:id)
    user_ids = Member.where(project_id: project_ids).distinct.pluck(:user_id)
    @messages = VacationMessage.listed_for(User.current, user_ids: user_ids)
    render :index
  end

  # User search for the substitute field and the pickers (My page block,
  # dashboards, home page setting, recipients). Active users the current user
  # may see (Redmine's users_visibility); +exclude+ drops one id, e.g. the
  # absent person; +groups+ adds groups, marked as such.
  def autocomplete_users
    term = params[:term].to_s
    users = User.active.visible.like(term).sorted.limit(20)
    users = users.where.not(id: params[:exclude].to_i) if params[:exclude].present?
    result = users.map { |u| { id: u.id, label: u.name, value: u.name } }

    if params[:groups].present?
      group_label = l(:label_group)
      result += Group.givable.like(term).sorted.limit(10).map do |g|
        label = "#{g.name} (#{group_label})"
        { id: g.id, label: label, value: label }
      end
    end

    render json: result
  end
end
