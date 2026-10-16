class VacationOverviewController < ApplicationController
  menu_item :vacation_overview

  before_action :require_login, only: [:index]
  before_action :find_project_by_project_id, :authorize, only: [:project]

  helper :vacation_messages
  helper :avatars

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
end
