class VacationMessage < ActiveRecord::Base
  include Redmine::SafeAttributes
  include Redmine::I18n

  VISIBILITIES = %w(all logged projects project_members selected).freeze
  MAX_LEAD_DAYS = 365

  # Presets offered on the form. The first three match Redmine's own flash
  # colours (error / warning / notice).
  COLOR_PRESETS = {
    'red'    => '#ffe3e3',
    'yellow' => '#ffebc1',
    'green'  => '#dfffdf',
    'blue'   => '#dbeafe',
    'grey'   => '#eeeeee'
  }.freeze

  belongs_to :user
  belongs_to :author,     class_name: 'User', optional: true
  belongs_to :substitute, class_name: 'User', optional: true
  has_and_belongs_to_many :principals,
                          join_table: 'vacation_messages_principals',
                          association_foreign_key: 'principal_id'
  has_and_belongs_to_many :projects,
                          join_table: 'vacation_messages_projects'

  validates :user, :date_from, :date_until, :text, presence: true
  validates :text, length: { maximum: 255 }
  validates :color, format: { with: /\A#\h{6}\z/ }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :lead_days, numericality: { only_integer: true, greater_than_or_equal_to: 0,
                                        less_than_or_equal_to: MAX_LEAD_DAYS }
  validate  :validate_date_range
  validate  :validate_recipients
  validate  :validate_projects
  validate  :validate_substitute

  before_validation { self.color = color.to_s.strip.downcase }
  before_save       { self.display_from = date_from - lead_days.to_i }

  # user_id is deliberately not listed: the controller sets the owner, and
  # only managers may pick someone other than themselves.
  safe_attributes 'date_from', 'date_until', 'text', 'color', 'visibility',
                  'show_to_self', 'append_dates', 'principal_ids',
                  'project_ids', 'include_subprojects',
                  'substitute_id', 'lead_days', 'show_banner'

  # Plugin labels live under field_vacation_* so they never override core
  # keys such as field_text ("Text field").
  def self.human_attribute_name(attr, *args)
    ::I18n.t("field_vacation_#{attr}", default: super)
  end

  scope :sorted,    -> { order(:date_from, :date_until, :id) }
  scope :active_on, ->(date) { where('date_from <= ? AND date_until >= ?', date, date) }
  scope :upcoming,  ->(date) { where('date_until >= ?', date) }
  scope :past,      ->(date) { where('date_until < ?', date) }
  scope :with_active_user, -> { joins(:user).where(users: { status: User::STATUS_ACTIVE }) }

  def self.setting_ids(key)
    Array(Setting.plugin_redmine_vacation[key]).reject(&:blank?).map(&:to_i)
  end

  # Admins and members of the manager groups may maintain absences for
  # everyone, not just for themselves.
  def self.manager?(user)
    return false unless user&.logged?
    return true if user.admin?

    ids = setting_ids('manager_group_ids')
    ids.any? && user.group_ids.intersect?(ids)
  end

  # Whether +user+ may maintain absences at all. Managers always may;
  # otherwise the plugin setting restricts it to members of the configured
  # groups (empty = everyone logged in).
  def self.manageable_by?(user)
    return false unless user&.logged?
    return true if manager?(user)

    ids = setting_ids('allowed_group_ids')
    ids.empty? || user.group_ids.intersect?(ids)
  end

  # How many days ahead the assignee hint warns about an absence.
  def self.hint_days
    days = Setting.plugin_redmine_vacation['hint_days'].to_i
    days.positive? ? days : 14
  end

  # Everything +viewer+ may see around today: running absences, absences in
  # their lead time and absences starting within hint_days. Banner, badges
  # and the assignee hint are all derived from this list, which is memoised
  # per request because several hooks ask for it.
  def self.relevant_for(viewer)
    VacationMessage::Current.relevant[viewer.id] ||= begin
      today = viewer.today
      upcoming(today)
        .where('display_from <= ? OR date_from <= ?', today, today + hint_days)
        .with_active_user
        .includes(:user, :substitute, :principals, :projects)
        .sorted
        .select { |message| message.visible_to?(viewer) }
    end
  end

  # Banners for the top of the page.
  def self.displayed_for(viewer)
    today = viewer.today
    relevant_for(viewer).select { |m| m.show_banner? && m.display_from <= today }
  end

  # Absences +viewer+ may see that are running today, one per user.
  def self.absent_today_for(viewer)
    today = viewer.today
    relevant_for(viewer).select { |m| m.active_on?(today) }.uniq(&:user_id)
  end

  # The next relevant absence per user id, for the assignee hint.
  def self.assignee_hints_for(viewer)
    relevant_for(viewer).each_with_object({}) { |m, hints| hints[m.user_id] ||= m }
  end

  # Current and upcoming absences +viewer+ may see, for the overview page.
  # Unlike the banner, the viewer's own absences are always included.
  def self.listed_for(viewer, user_ids: nil)
    scope = upcoming(viewer.today).with_active_user
              .includes(:user, :substitute, :principals, :projects)
              .sorted
    scope = scope.where(user_id: user_ids) if user_ids
    scope.select { |m| m.user_id == viewer.id || m.visible_to?(viewer) }
  end

  def visible_to?(viewer)
    return false if viewer.nil?
    return show_to_self? if viewer.id == user_id

    case visibility
    when 'all'             then true
    when 'logged'          then viewer.logged?
    when 'projects'        then viewer.logged? && shares_project_with?(viewer)
    when 'project_members' then viewer.logged? && project_member?(viewer)
    when 'selected'        then viewer.logged? && recipient?(viewer)
    else false
    end
  end

  def active_on?(date)
    date_from <= date && date_until >= date
  end

  def single_day?
    date_from == date_until
  end

  # The texts below live in the model because they are rendered from hooks,
  # where only core helpers are available. format_date and l come from
  # Redmine::I18n.

  def period_text
    single_day? ? format_date(date_from) : "#{format_date(date_from)} - #{format_date(date_until)}"
  end

  # Text as shown in the banner. The period is always appended while the
  # banner is shown ahead of the absence, otherwise it would be unclear when
  # the absence starts.
  def banner_text(today)
    show_period = append_dates? || today < date_from
    show_period ? "#{text} (#{period_text})" : text
  end

  # One plain-text line for the assignee hint and the badge tooltip.
  def hint_text(today)
    key = today < date_from ? :text_vacation_hint_upcoming : :text_vacation_hint_absent
    line = l(key, name: user.name, date: format_date(date_from), text: "#{text} (#{period_text})")
    line += " - #{l(:field_vacation_substitute_id)}: #{substitute.name}" if substitute
    line
  end

  # The author may only pick projects they can see. Projects already assigned
  # are kept even if the author lost access in between, so editing the text
  # does not silently drop them.
  def project_ids=(ids)
    ids = Array(ids).reject(&:blank?).map(&:to_i)
    allowed = Project.visible(user || User.current).where(id: ids).pluck(:id)
    allowed |= projects.pluck(:id) & ids if persisted?
    super(ids & allowed)
  end

  # Ids of the projects whose members see the banner: the selected ones and,
  # with include_subprojects, all their descendants. Archived projects and
  # those scheduled for deletion are left out.
  def target_project_ids
    selected = projects.to_a
    return [] if selected.empty?

    scope = Project.where(status: [Project::STATUS_ACTIVE, Project::STATUS_CLOSED])
    if include_subprojects?
      table = Project.table_name
      condition = selected.map { |p| "(#{table}.lft >= #{p.lft.to_i} AND #{table}.rgt <= #{p.rgt.to_i})" }
      scope.where(condition.join(' OR ')).pluck(:id)
    else
      scope.where(id: selected.map(&:id)).pluck(:id)
    end
  end

  # Inline style for the banner: the chosen colour as background, a darker
  # shade of it as border and a text colour that stays readable on it.
  def css_style
    rgb = color.delete('#').scan(/../).map { |c| c.to_i(16) }
    luminance = (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255
    border = shade(rgb, 0.7)
    text   = luminance > 0.6 ? shade(rgb, 0.3) : '#ffffff'
    "background-color: #{color}; border-color: #{border}; color: #{text};"
  end

  # Changes whenever the message is edited, so a banner dismissed in the
  # browser comes back after an update.
  def dismiss_key
    "#{id}-#{updated_on.to_i}"
  end

  private

  def shade(rgb, factor)
    '#' + rgb.map { |c| format('%02x', (c * factor).round) }.join
  end

  def shares_project_with?(viewer)
    (Member.where(user_id: viewer.id).pluck(:project_id) &
     Member.where(user_id: user_id).pluck(:project_id)).any?
  end

  def project_member?(viewer)
    ids = target_project_ids
    ids.any? && Member.where(user_id: viewer.id, project_id: ids).exists?
  end

  def recipient?(viewer)
    ids = principal_ids
    ids.include?(viewer.id) || viewer.group_ids.intersect?(ids)
  end

  def validate_date_range
    return if date_from.blank? || date_until.blank?

    errors.add(:date_until, :greater_than_start_date) if date_until < date_from
  end

  def validate_recipients
    return unless visibility == 'selected' && principal_ids.empty?

    errors.add(:base, l(:error_vacation_no_recipients))
  end

  def validate_projects
    return unless visibility == 'project_members' && project_ids.empty?

    errors.add(:base, l(:error_vacation_no_projects))
  end

  def validate_substitute
    return if substitute_id.blank?

    if substitute_id == user_id || !substitute&.active?
      errors.add(:substitute_id, :invalid)
    end
  end
end
