# Per-request cache for VacationMessage.relevant_for. Rails resets
# CurrentAttributes around every request, so nothing leaks between users.
class VacationMessage::Current < ActiveSupport::CurrentAttributes
  attribute :relevant

  def relevant
    super || (self.relevant = {})
  end
end
