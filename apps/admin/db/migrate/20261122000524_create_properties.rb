class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.string :name, null: false
      t.string :address, null: false
      t.string :city, null: false
      t.string :state, null: false
      t.string :sanity_slug
      # Counter cache for Unit's belongs_to :property (SPEC §5 "unit_count").
      t.integer :units_count, null: false, default: 0

      t.timestamps
    end

    # Slug is optional, but unique when set (it keys the Sanity listing, SPEC §6).
    add_index :properties, :sanity_slug, unique: true, where: "sanity_slug IS NOT NULL"
  end
end
