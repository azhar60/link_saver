class Links::ArchivesController < ApplicationController
  before_action :set_link

  def create
    @link.archive!
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@link) }
      format.html         { redirect_to @link, notice: "Link archived.", status: :see_other }
    end
  end

  def destroy
    @link.unarchive!
    redirect_to @link, notice: "Link restored.", status: :see_other
  end

  private

  def set_link
    @link = Link.find(params[:link_id])
  end
end
