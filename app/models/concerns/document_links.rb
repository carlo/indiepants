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
      if populate_links?
        Background.go { populate_links! }
      end
    end
  end

  # Is it time to (re)populate this document's links?
  #
  def populate_links?
    html_changed? || title_changed? || path_changed?
  end

  # (Re)populate this document's links.
  #
  def populate_links!
    # Remember these for later
    marked_for_deletion = outgoing_links.pluck(:id)

    selector_map = {
      'link[rel="in-reply-to"]' => 'reply',
      'a.u-in-reply-to' => 'reply',
      'a.u-like-of' => 'like',
      'a.u-repost-of' => 'repost'
    }

    # create new links depending on content
    Nokogiri::HTML(html).css(selector_map.keys.join(', ')).each do |el|
      # Find an existing document matching the given URL, or create
      # a new, temporary one (we're not saving.)
      href   = URI.join(user.url, el['href'])
      target = Pants::Document.for_url(href)
      link   = Pants::Link.where(source: self, target: target).first_or_initialize

      # Analyze the actual HTML link
      link.rels = []
      selector_map.each do |selector, rel|
        if el.matches?(selector)
          link.rels << rel
        end
      end

      # We're only interested in links to existing local documents.
      if target.local? && target.persisted?
        link.target = target
        link.save!

        # We don't need to delete this one
        marked_for_deletion.delete(link.id)
      elsif local? && target.remote?
        # Send a webmention, then discard this link.
        send_webmention(target.url)
      end
    end

    # Let's delete those that are still marked for deletion
    if marked_for_deletion.any?
      outgoing_links.where(id: marked_for_deletion).destroy_all
    end

    # For every local document that we're linking to, update the link counts.
    targets = outgoing_links.map { |link| link.target }.uniq
    targets.each(&:update_link_counts!)
  end

  def update_link_counts!
    self.number_of_likes   = incoming_links.rel("like").count
    self.number_of_replies = incoming_links.rel("reply").count
    self.number_of_reposts = incoming_links.rel("repost").count
    save!
  end

  def send_webmention(target)
    if endpoint = Webmention::Client.supports_webmention?(target)
      Webmention::Client.send_mention(endpoint, url, target)
    end
  end
end
