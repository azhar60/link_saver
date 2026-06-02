class ProcessLinkJob < ApplicationJob
  queue_as :default

  def perform(link_id)
    link = Link.find_by(id: link_id)
    return unless link

    link.update(status: :processing)
    link.process_via_ai
    link.save
  end
end
