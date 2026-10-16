class VacationMessagesController < ApplicationController
  self.main_menu = false

  before_action :require_login
  before_action :authorize_vacation_messages
  before_action :find_vacation_message, only: [:edit, :update, :destroy]

  helper :vacation_messages

  def index
    today = User.current.today
    scope = VacationMessage.where(user_id: User.current.id).includes(:principals)
    @upcoming = scope.upcoming(today).sorted.to_a
    @past     = scope.past(today).order(date_from: :desc).to_a
  end

  def new
    @vacation_message = VacationMessage.new(user: User.current)
  end

  def create
    @vacation_message = VacationMessage.new(user: User.current)
    @vacation_message.safe_attributes = params[:vacation_message]
    if @vacation_message.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to vacation_messages_path
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
      redirect_to vacation_messages_path
    else
      render :edit
    end
  end

  def destroy
    @vacation_message.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to vacation_messages_path
  end

  private

  def authorize_vacation_messages
    deny_access unless VacationMessage.manageable_by?(User.current)
  end

  # Users only ever see and touch their own absences.
  def find_vacation_message
    @vacation_message = VacationMessage.where(user_id: User.current.id).find_by(id: params[:id])
    render_404 unless @vacation_message
  end
end
