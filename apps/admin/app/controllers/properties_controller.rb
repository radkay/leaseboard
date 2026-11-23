class PropertiesController < ApplicationController
  before_action :set_property, only: %i[ show edit update ]

  # GET /properties or /properties.json
  def index
    @properties = Property.strict_loading.order(:name)
  end

  # GET /properties/1 or /properties/1.json
  def show
    # One query over the status view for the units table (no N+1).
    @rent_roll = RentRoll.new(@property)
  end

  # GET /properties/new
  def new
    @property = Property.new
  end

  # GET /properties/1/edit
  def edit
  end

  # POST /properties or /properties.json
  def create
    @property = Property.new(property_params)

    respond_to do |format|
      if @property.save
        format.html { redirect_to @property, notice: "Property was successfully created." }
        format.json { render :show, status: :created, location: @property }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @property.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /properties/1 or /properties/1.json
  def update
    respond_to do |format|
      if @property.update(property_params)
        format.html { redirect_to @property, notice: "Property was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @property }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @property.errors, status: :unprocessable_content }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_property
      @property = Property.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def property_params
      params.expect(property: [ :name, :address, :city, :state, :sanity_slug ])
    end
end
