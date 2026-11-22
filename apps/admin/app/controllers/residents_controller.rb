class ResidentsController < ApplicationController
  before_action :set_resident, only: %i[ show edit update destroy ]

  # GET /residents or /residents.json
  def index
    @residents = Resident.strict_loading.order(:last_name, :first_name)
  end

  # GET /residents/1 or /residents/1.json
  def show
  end

  # GET /residents/new
  def new
    @resident = Resident.new
  end

  # GET /residents/1/edit
  def edit
  end

  # POST /residents or /residents.json
  def create
    @resident = Resident.new(resident_params)

    respond_to do |format|
      if @resident.save
        format.html { redirect_to @resident, notice: "Resident was successfully created." }
        format.json { render :show, status: :created, location: @resident }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @resident.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /residents/1 or /residents/1.json
  def update
    respond_to do |format|
      if @resident.update(resident_params)
        format.html { redirect_to @resident, notice: "Resident was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @resident }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @resident.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /residents/1 or /residents/1.json
  def destroy
    @resident.destroy!

    respond_to do |format|
      format.html { redirect_to residents_path, notice: "Resident was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_resident
      @resident = Resident.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def resident_params
      params.expect(resident: [ :first_name, :last_name, :email, :phone ])
    end
end
