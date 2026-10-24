class CreateUserActivities < ActiveRecord::Migration[8.1]
  def change
    # NOTE: the history of the activity of an account - the small bar chart
    # under the "last activity" column is built out of these rows.
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    # IMPORTANT: the index for the query that builds the chart - it reads the
    # activity of many users at once.
    add_index :user_activities, [:user_id, :occurred_at]
  end
end
