class VacationMessagesController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :authorize_vacation_messages
  before_action :find_owner, only: [:index, :new, :create, :autocomplete_projects]
  before_action :find_vacation_message, only: [:edit, :update, :destroy]

  helper :vacation_messages

  def index
    today = User.current.today
    scope = VacationMessage.where(user_id: @owner.id).includes(:principals, :projects, :substitute)
    @upcoming = scope.upcoming(today).sorted.to_a
    @past     = scope.past(today).order(date_from: :desc).to_a
  end

  def new
    @vacation_message = VacationMessage.new(user: @owner)
  end

  def create
    @vacation_message = VacationMessage.new(user: @owner, author: User.current)
    @vacation_message.safe_attributes = params[:vacation_message]
    if @vacation_message.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to list_path
    else
      render :new
    end
  end

  def edit
  end

  def update
    # Assigning habtm ids on a persisted record writes the join rows at once,
    # so roll them back if the record turns out to be invalid.
    saved = VacationMessage.transaction do
      @vacation_message.safe_attributes = params[:vacation_message]
      @vacation_message.save || raise(ActiveRecord::Rollback)
    end
    if saved
      flash[:notice] = l(:notice_successful_update)
      redirect_to list_path
    else
      render :edit
    end
  end

  def destroy
    @vacation_message.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to list_path
  end

  # Project search for the visibility "members of selected projects":
  # projects the absent person can see, labelled with their parents.
  def autocomplete_projects
    projects = Project.visible(@owner).like(params[:term].to_s).sorted.limit(20).to_a
    render json: projects.map { |project|
      label = VacationMessage.project_label(project)
      { id: project.id, label: label, value: label }
    }
  end

  private

  def manager?
    VacationMessage.manager?(User.current)
  end
  helper_method :manager?

  def authorize_vacation_messages
    deny_access unless VacationMessage.manageable_by?(User.current)
  end

  # Whose absences are listed or created. Everyone works on their own;
  # managers may pass user_id (as query parameter or in the form).
  def find_owner
    @owner = User.current
    return unless manager?

    user_id = params[:user_id].presence || params.dig(:vacation_message, :user_id).presence
    return unless user_id

    @owner = User.active.find_by(id: user_id)
    render_404 unless @owner
  end

  # Users only ever see and touch their own absences; managers everyone's.
  def find_vacation_message
    scope = manager? ? VacationMessage.all : VacationMessage.where(user_id: User.current.id)
    @vacation_message = scope.find_by(id: params[:id])
    if @vacation_message
      @owner = @vacation_message.user
    else
      render_404
    end
  end

  def list_path
    @owner == User.current ? vacation_messages_path : vacation_messages_path(user_id: @owner.id)
  end
end
