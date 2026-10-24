class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # NOTE: "name" is the human readable name shown in the admin table.
      t.string :name, null: false
      # NOTE: e-mail is NOT NULL - the unique index below is the real guarantee.
      t.string :email, null: false
      # NOTE: only the bcrypt digest is stored, never the plain password.
      t.string :password_digest, null: false
      # NOTE: blocked == true means the account is suspended by an administrator.
      t.boolean :blocked, null: false, default: false
      # NOTE: last_login_at - updated every time the user signs in successfully.
      t.datetime :last_login_at
      # NOTE: last_activity_at - updated on every authenticated request.
      t.datetime :last_activity_at
      t.timestamps
    end

    # ---------------------------------------------------------------------------
    # IMPORTANT: a REAL unique index on the e-mail column.
    #
    # The task explicitly says the guarantee must not live in application code:
    # "YOUR STORAGE SHOULD GUARANTEE E-MAIL UNIQUENESS INDEPENDENTLY OF HOW MANY
    # SOURCES PUSH DATA INTO IT SIMULTANEOUSLY."
    #
    # A unique index is enforced by PostgreSQL itself. Two concurrent INSERTs with
    # the same e-mail cannot both succeed: the second one raises
    # ActiveRecord::RecordNotUnique. No amount of application level "SELECT
    # first" logic can be fooled by a race.
    #
    # NOTA BENE: this index is NOT the primary key. The primary key is the
    # implicit "users_pkey" index on the `id` column. Both exist on purpose.
    # ---------------------------------------------------------------------------
    add_index :users, :email, unique: true, name: "index_users_on_email"

    # NOTE: second, defence-in-depth unique index on the CASE FOLDED e-mail.
    # The model down-cases every e-mail before saving, so both indexes normally
    # agree. This one additionally protects the table when a row is written by a
    # data loader / raw SQL / another service that bypasses the model.
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"

    # NOTE: the admin table is sorted by the last login time, so the column is
    # indexed to keep the ORDER BY cheap.
    add_index :users, :last_login_at, name: "index_users_on_last_login_at"
    add_index :users, :last_activity_at, name: "index_users_on_last_activity_at"
    add_index :users, :blocked, name: "index_users_on_blocked"
  end
end
