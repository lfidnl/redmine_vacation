class VacationMessage < ActiveRecord::Base
  include Redmine::SafeAttributes
  include Redmine::I18n

  VISIBILITIES = %w(all logged projects selected).freeze

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
  has_and_belongs_to_many :principals,
                          join_table: 'vacation_messages_principals',
                          association_foreign_key: 'principal_id'

  validates :user, :date_from, :date_until, :text, presence: true
  validates :text, length: { maximum: 255 }
  validates :color, format: { with: /\A#\h{6}\z/ }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate  :validate_date_range
  validate  :validate_recipients

  before_validation { self.color = color.to_s.strip.downcase }

  safe_attributes 'date_from', 'date_until', 'text', 'color', 'visibility',
                  'show_to_self', 'append_dates', 'principal_ids'

  # Plugin labels live under field_vacation_* so they never override core
  # keys such as field_text ("Text field").
  def self.human_attribute_name(attr, *args)
    ::I18n.t("field_vacation_#{attr}", default: super)
  end

  scope :sorted,    -> { order(:date_from, :date_until, :id) }
  scope :active_on,  ->(date) { where('date_from <= ? AND date_until >= ?', date, date) }
  scope :upcoming,   ->(date) { where('date_until >= ?', date) }
  scope :past,       ->(date) { where('date_until < ?', date) }

  # Whether +user+ may maintain absences at all. Admins always may; otherwise
  # the plugin setting restricts it to members of the configured groups.
  def self.manageable_by?(user)
    return false unless user&.logged?
    return true if user.admin?

    group_ids = Array(Setting.plugin_redmine_vacation['allowed_group_ids']).reject(&:blank?).map(&:to_i)
    group_ids.empty? || user.group_ids.intersect?(group_ids)
  end

  # Messages running today that +viewer+ is allowed to see.
  def self.displayed_for(viewer)
    active_on(viewer.today)
      .joins(:user).where(users: { status: User::STATUS_ACTIVE })
      .includes(:user, :principals)
      .sorted
      .select { |message| message.visible_to?(viewer) }
  end

  def visible_to?(viewer)
    return false if viewer.nil?
    return show_to_self? if viewer.id == user_id

    case visibility
    when 'all'      then true
    when 'logged'   then viewer.logged?
    when 'projects' then viewer.logged? && shares_project_with?(viewer)
    when 'selected' then viewer.logged? && recipient?(viewer)
    else false
    end
  end

  def single_day?
    date_from == date_until
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

  private

  def shade(rgb, factor)
    '#' + rgb.map { |c| format('%02x', (c * factor).round) }.join
  end

  def shares_project_with?(viewer)
    (Member.where(user_id: viewer.id).pluck(:project_id) &
     Member.where(user_id: user_id).pluck(:project_id)).any?
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
end
