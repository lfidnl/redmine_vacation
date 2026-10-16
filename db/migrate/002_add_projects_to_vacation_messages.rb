class AddProjectsToVacationMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :vacation_messages, :include_subprojects, :boolean, null: false, default: true

    # Projects for visibility "project_members": their members see the banner.
    create_table :vacation_messages_projects, id: false do |t|
      t.integer :vacation_message_id, null: false
      t.integer :project_id,          null: false
    end

    add_index :vacation_messages_projects,
              [:vacation_message_id, :project_id],
              unique: true, name: 'index_vacation_messages_projects_unique'
    add_index :vacation_messages_projects, :project_id
  end
end
