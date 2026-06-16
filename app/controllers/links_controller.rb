class LinksController < ApplicationController
  before_action :set_link, only: %i[ show edit update destroy regenerate ]

  # GET /links or /links.json
  def index
    @tag = params[:tag].presence
    @query = params[:q].presence
    @show_archived = ActiveModel::Type::Boolean.new.cast(params[:archived])
    scope = @show_archived ? Link.archived : Link.active
    scope = scope.order(created_at: :desc)
    scope = scope.tagged_with(@tag) if @tag
    scope = scope.search(@query) if @query
    @pagy, @links = pagy(scope)
  end

  # GET /links/1 or /links/1.json
  def show
  end

  # GET /links/new
  def new
    @link = Link.new(prefill_params)
  end

  # GET /links/1/edit
  def edit
  end

  # POST /links or /links.json
  def create
    @link = Link.new(link_params)

    respond_to do |format|
      if @link.save
        ProcessLinkJob.perform_later(@link.id)
        format.html { redirect_to @link, notice: "Saved! Fetching the page and summarizing in the background." }
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
    @link.update(status: :pending)
    ProcessLinkJob.perform_later(@link.id)
    redirect_to @link, notice: "Regenerating in the background."
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

    # Used by the bookmarklet to pre-fill /links/new from the page the user is on.
    def prefill_params
      return {} unless params[:link].is_a?(ActionController::Parameters)
      params[:link].permit(:url, :title)
    end
end
