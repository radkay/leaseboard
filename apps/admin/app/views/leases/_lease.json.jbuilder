json.extract! lease, :id, :unit_id, :resident_id, :start_date, :end_date, :monthly_rent, :status, :notice_date, :move_out_date, :created_at, :updated_at
json.url lease_url(lease, format: :json)
