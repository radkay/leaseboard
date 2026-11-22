class CreateLeases < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :leases do |t|
      t.references :unit, null: false, foreign_key: true
      t.references :resident, null: false, foreign_key: true
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.decimal :monthly_rent, precision: 10, scale: 2, null: false
      t.string :status, null: false
      t.date :notice_date
      t.date :move_out_date

      t.timestamps
    end

    add_check_constraint :leases, "monthly_rent > 0", name: "leases_monthly_rent_positive"
    add_check_constraint :leases, "end_date > start_date", name: "leases_end_after_start"
    add_check_constraint :leases,
      "status IN ('pending', 'active', 'notice_given', 'ended')",
      name: "leases_status_valid"

    # A unit can't have two live (non-ended) leases whose occupancy periods overlap.
    # This protects the status derivation (a unit has at most one lease covering any
    # date) and the "new lease starts after move-out" rule. btree_gist supplies the
    # equality operator class so unit_id (=) and the daterange (&&) share one GiST index.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE leases ADD CONSTRAINT leases_no_overlapping_live_leases
          EXCLUDE USING gist (
            unit_id WITH =,
            daterange(start_date, end_date, '[]') WITH &&
          ) WHERE (status <> 'ended');
        SQL
      end
      dir.down do
        execute "ALTER TABLE leases DROP CONSTRAINT leases_no_overlapping_live_leases"
      end
    end
  end
end
