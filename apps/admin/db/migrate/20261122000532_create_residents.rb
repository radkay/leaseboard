class CreateResidents < ActiveRecord::Migration[8.1]
  def change
    create_table :residents do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone, null: false

      t.timestamps
    end

    add_index :residents, "lower(email)", unique: true, name: "index_residents_on_lower_email"
  end
end
