class AddSubstituteLeadAndBannerToVacationMessages < ActiveRecord::Migration[7.2]
  def up
    add_column :vacation_messages, :substitute_id, :integer
    add_column :vacation_messages, :author_id,     :integer
    add_column :vacation_messages, :lead_days,     :integer, null: false, default: 0
    add_column :vacation_messages, :show_banner,   :boolean, null: false, default: true
    # date_from - lead_days, kept in its own column so the "shown from" check
    # stays a plain, database-independent comparison.
    add_column :vacation_messages, :display_from,  :date

    execute 'UPDATE vacation_messages SET display_from = date_from, author_id = user_id'
    change_column_null :vacation_messages, :display_from, false

    add_index :vacation_messages, :display_from
    add_index :vacation_messages, :substitute_id
  end

  def down
    remove_index  :vacation_messages, :substitute_id
    remove_index  :vacation_messages, :display_from
    remove_column :vacation_messages, :display_from
    remove_column :vacation_messages, :show_banner
    remove_column :vacation_messages, :lead_days
    remove_column :vacation_messages, :author_id
    remove_column :vacation_messages, :substitute_id
  end
end
