class UnitsController < ApplicationController
  before_action :set_unit, only: %i[ show edit update sign_new_lease ]

  # GET /units or /units.json
  def index
    @units = Unit.includes(:property).strict_loading.order(:property_id, :number)
  end

  # GET /units/1 or /units/1.json
  def show
    # All of the unit's leases, newest first, with residents preloaded (no N+1).
    @leases = @unit.leases.includes(:resident).order(start_date: :desc, id: :desc).strict_loading
  end

  # GET /units/new
  def new
    @unit = Unit.new
  end

  # GET /units/1/edit
  def edit
  end

  # POST /units or /units.json
  def create
    @unit = Unit.new(unit_params)

    respond_to do |format|
      if @unit.save
        format.html { redirect_to @unit, notice: "Unit was successfully created." }
        format.json { render :show, status: :created, location: @unit }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @unit.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /units/1 or /units/1.json
  def update
    respond_to do |format|
      if @unit.update(unit_params)
        format.html { redirect_to @unit, notice: "Unit was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @unit }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @unit.errors, status: :unprocessable_content }
      end
    end
  end

  # POST /units/1/sign_new_lease
  def sign_new_lease
    @lease = Leases::SignNewLease.call(
      unit: @unit,
      resident_attributes: params.expect(resident: [ :first_name, :last_name, :email, :phone ]).to_h,
      start_date: params.expect(:start_date),
      end_date: params.expect(:end_date),
      monthly_rent: params.expect(:monthly_rent)
    )
    respond_to do |format|
      format.turbo_stream # sign_new_lease.turbo_stream.erb: prepend the row, reset the form
      format.html { redirect_to @lease, notice: "New lease signed." }
    end
  rescue ActiveRecord::RecordInvalid => e
    @errors = e.record.errors.full_messages
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "new_lease_form", partial: "units/new_lease_form", locals: { unit: @unit, errors: @errors }
        ), status: :unprocessable_content
      end
      format.html { redirect_to @unit, alert: "Could not sign lease: #{@errors.to_sentence}" }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_unit
      @unit = Unit.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def unit_params
      params.expect(unit: [ :property_id, :number, :bedrooms, :bathrooms, :sq_ft, :market_rent ])
    end
end
