class CreateVacationMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :vacation_messages do |t|
      t.integer  :user_id,      null: false
      t.date     :date_from,    null: false
      t.date     :date_until,   null: false
      t.string   :text,         null: false, limit: 255
      t.string   :color,        null: false, limit: 7, default: '#ffe3e3'
      t.string   :visibility,   null: false, limit: 20, default: 'logged'
      t.boolean  :show_to_self, null: false, default: false
      t.boolean  :append_dates, null: false, default: true
      t.datetime :created_on
      t.datetime :updated_on
    end

    add_index :vacation_messages, :user_id
    add_index :vacation_messages, [:date_from, :date_until]

    # Recipients for visibility "selected": users and/or groups (both live in
    # the users table as Principal subclasses).
    create_table :vacation_messages_principals, id: false do |t|
      t.integer :vacation_message_id, null: false
      t.integer :principal_id,        null: false
    end

    add_index :vacation_messages_principals,
              [:vacation_message_id, :principal_id],
              unique: true, name: 'index_vacation_messages_principals_unique'
    add_index :vacation_messages_principals, :principal_id
  end
end
