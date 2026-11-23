class LeasesController < ApplicationController
  before_action :set_lease, only: %i[ show edit update give_notice sign_renewal ]

  # GET /leases/1 or /leases/1.json
  def show
  end

  # GET /leases/new
  def new
    @lease = Lease.new
  end

  # GET /leases/1/edit
  def edit
  end

  # POST /leases or /leases.json
  def create
    @lease = Lease.new(lease_params)

    respond_to do |format|
      if @lease.save
        format.html { redirect_to @lease, notice: "Lease was successfully created." }
        format.json { render :show, status: :created, location: @lease }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @lease.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /leases/1 or /leases/1.json
  def update
    respond_to do |format|
      if @lease.update(lease_params)
        format.html { redirect_to @lease, notice: "Lease was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @lease }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @lease.errors, status: :unprocessable_content }
      end
    end
  end


  # POST /leases/1/give_notice
  def give_notice
    Leases::GiveNotice.call(@lease, move_out_date: params.expect(:move_out_date))
    redirect_to @lease, notice: "Notice recorded."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @lease, alert: "Could not record notice: #{e.record.errors.full_messages.to_sentence}"
  end

  # POST /leases/1/sign_renewal
  def sign_renewal
    renewal = Leases::SignRenewal.call(
      @lease,
      new_end_date: params.expect(:new_end_date),
      monthly_rent: params.expect(:monthly_rent)
    )
    redirect_to renewal, notice: "Renewal signed."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @lease, alert: "Could not sign renewal: #{e.record.errors.full_messages.to_sentence}"
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_lease
      @lease = Lease.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def lease_params
      params.expect(lease: [ :unit_id, :resident_id, :start_date, :end_date, :monthly_rent, :status, :notice_date, :move_out_date ])
    end
end
