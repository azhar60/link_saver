class LinksController < ApplicationController
  before_action :set_link, only: %i[ show edit update destroy regenerate ]

  # GET /links or /links.json
  def index
    @links = Link.all
  end

  # GET /links/1 or /links/1.json
  def show
  end

  # GET /links/new
  def new
    @link = Link.new
  end

  # GET /links/1/edit
  def edit
  end

  # POST /links or /links.json
  def create
    @link = Link.new(link_params)

    fetch_succeeded = @link.valid? ? @link.process_via_ai : true

    respond_to do |format|
      if @link.save
        flash[:alert] = "Saved, but couldn't fetch the page — title set from the URL." unless fetch_succeeded
        format.html { redirect_to @link, notice: "Link was successfully created." }
        format.json { render :show, status: :created, location: @link }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @link.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /links/1 or /links/1.json
  def update
    respond_to do |format|
      if @link.update(link_params)
        format.html { redirect_to @link, notice: "Link was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @link }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @link.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /links/1/regenerate
  def regenerate
    @link.process_via_ai
    @link.save
    redirect_to @link, notice: @link.ready? ? "Summary regenerated." : "Couldn't generate a summary — try again later."
  end

  # DELETE /links/1 or /links/1.json
  def destroy
    @link.destroy!

    respond_to do |format|
      format.html { redirect_to links_path, notice: "Link was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_link
      @link = Link.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def link_params
      params.expect(link: [ :url, :title, :summary, :tags, :status ])
    end
end
