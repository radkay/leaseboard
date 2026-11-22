class CreateUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :units do |t|
      # Deferrable so fixtures load without superuser (see CreateLeases).
      t.references :property, null: false, foreign_key: { deferrable: :deferred }
      t.string :number, null: false
      t.integer :bedrooms, null: false
      t.decimal :bathrooms, precision: 3, scale: 1, null: false
      t.integer :sq_ft, null: false
      t.decimal :market_rent, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :units, [ :property_id, :number ], unique: true

    add_check_constraint :units, "bedrooms >= 0", name: "units_bedrooms_non_negative"
    add_check_constraint :units, "bathrooms > 0", name: "units_bathrooms_positive"
    add_check_constraint :units, "sq_ft > 0", name: "units_sq_ft_positive"
    add_check_constraint :units, "market_rent > 0", name: "units_market_rent_positive"
  end
end
