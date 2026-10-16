module RedmineVacation
  # Adds the absence block to the dashboards of the additionals plugin
  # (welcome page and project dashboards). Only included when additionals is
  # installed, see init.rb.
  module DashboardContentPatch
    extend ActiveSupport::Concern

    included do
      prepend InstanceOverwriteMethods
    end

    module InstanceOverwriteMethods
      def block_definitions
        blocks = super

        blocks['vacation_messages'] = {
          label: l(:label_vacation_overview),
          partial: 'dashboards/blocks/vacation_messages',
          max_occurs: DashboardContent::MAX_MULTIPLE_OCCURS,
          # additionals merges block settings into the stored ones; the picker
          # always sends an empty marker, so "nobody selected" becomes [] and
          # replaces an earlier selection.
          settings_filter: lambda { |settings, _dashboard|
            { user_ids: VacationMessage.ids_from(settings[:user_ids]).map(&:to_s) }
          }
        }

        blocks
      end
    end
  end
end
