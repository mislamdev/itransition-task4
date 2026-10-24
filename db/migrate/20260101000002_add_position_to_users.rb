class AddPositionToUsers < ActiveRecord::Migration[8.1]
  def change
    # NOTE: the position (the job title) comes from the data set of the task
    # (users.json). It is a normal column of the user - nullable, because an
    # account that registers itself has no position.
    add_column :users, :position, :string
  end
end
