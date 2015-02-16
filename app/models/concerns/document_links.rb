concern :DocumentLinks do
  included do
    has_many :outgoing_links,
      class_name: "Pants::Link",
      as: "source",
      dependent: :destroy

    has_many :incoming_links,
      class_name: "Pants::Link",
      as: "target",
      dependent: :destroy

    after_save do
      if local?
        Background.go { populate_links_from(html) }
      end
    end
  end

  def populate_links_from(html)
    # Remember these for later
    marked_for_deletion = outgoing_links.pluck(:id)

    # create new links depending on content
    Nokogiri::HTML(html).css('a').each do |a|
      link = Pants::Link.new
      link.source = self
      link.rel    = a['rel']   # TODO: or analyze CSS

      target = Pants::Document.from_url(a['href'], fetch: false)

      # We don't want to create new local documents.
      unless target.local? && target.new_record?
        target.save!
        link.target = target
        link.save!

        # We don't need to delete this one
        marked_for_deletion.delete(link.id)
      end
    end

    # Let's delete those that are still marked for deletion
    if marked_for_deletion.any?
      outgoing_links.where(id: marked_for_deletion).destroy_all
    end

    # Update all linked documents
    outgoing_links.reload.each do |link|
      link.target.fetch!
      link.target.save!
    end
  end
end
