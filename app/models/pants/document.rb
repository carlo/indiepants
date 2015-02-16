class Pants::Document < ActiveRecord::Base
  acts_as_paranoid

  include DocumentTypeSupport
  include DocumentFetching

  scope :latest, -> { order("created_at DESC") }

  belongs_to :user,
    class_name: "Pants::User",
    foreign_key: "user_id",
    autosave: true

  before_validation do
    if local?
      # Publish new posts right away
      self.published_at = Time.now

      # Render HTML
      self.html = generate_html

      # Make sure a slug is available
      self.slug ||= generate_unique_slug

      # Update the path
      if path.blank? || (slug_was && slug_changed?)
        self.path = generate_path
      end
    end

    # Remember previous paths
    if persisted? && path_changed?
      self.previous_paths << path_was
    end
  end

  concerning :Links do
    included do
      has_many :outgoing_links,
        class_name: "Pants::Link",
        as: "source",
        dependent: :destroy

      has_many :incoming_links,
        class_name: "Pants::Link",
        as: "target",
        dependent: :destroy

      after_save { populate_links_from_html if local? }
    end

    def populate_links_from_html
      # purge existing links
      outgoing_links.delete_all

      # create new links depending on content
      Nokogiri::HTML(html).css('a').each do |a|
        Pants::Link.create! do |link|
          link.source = self
          link.rel    = a['rel']   # TODO: or analyze CSS

          target = Pants::Document.from_url(a['href'])
          target.save!
          link.target = target
        end
      end
    end
  end

  validates :slug,
    presence: true,
    uniqueness: { scope: :user_id },
    format: /\A[a-zA-Z0-9_-]+\Z/,
    if: -> { local? }

  def generate_html
    # By default, just set #html to itself. Of course, this method is
    # expected to be overloaded in child classes. Duh!
    #
    html
  end

  def generate_slug
    SecureRandom.hex(6)
  end

  # Generate a unique slug by adding a numerical, incremental suffix
  # if the generated_slug is already taken.
  #
  def generate_unique_slug
    slug = generate_slug
    candidate = slug
    i = 1
    while user.documents.where(slug: candidate).any?
      i += 1
      candidate = "#{slug}-#{i}"
    end
    candidate
  end

  def generate_path
    dt = published_at || created_at || Time.now

    [nil,
      dt.year.to_s.rjust(4, '0'),
      dt.month.to_s.rjust(2, '0'),
      dt.day.to_s.rjust(2, '0'),
      slug].join("/")
  end

  def local?
    user.try(:local?)
  end

  def remote?
    !local?
  end

  concerning :Url do
    def url
      URI.join(user.url, path).to_s
    end

    def url=(v)
      uri = URI(v)
      self.path = uri.path
      self.user = Pants::User.where(host: uri.host).first_or_initialize
      self.user.scheme = uri.scheme
    end
  end
end
