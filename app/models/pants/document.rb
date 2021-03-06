class Pants::Document < ActiveRecord::Base
  CONSUMABLE_ATTRIBUTES = %w[url uid type title html data tags meta published_at]

  acts_as_paranoid

  include Scopes
  include DocumentTypeSupport
  include DocumentFetching
  include DocumentLinks

  store_accessor :meta, :number_of_likes, :number_of_replies, :number_of_reposts

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

  include DocumentDeduplication

  after_create do
    if local? && uid.blank?
      update_columns(uid: URI.join(user.url, "/pants/documents/#{id}").to_s)
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
    SecureRandom.hex(12)
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

  def consume(attributes)
    attributes = attributes.with_indifferent_access

    # Copy over the attributes that we consider safe.
    self.attributes = attributes.slice(*CONSUMABLE_ATTRIBUTES)
    self
  end

  def local?
    user.try(:local?)
  end

  def remote?
    !local?
  end

  concerning :Uid do
    def uid=(v)
      write_attribute(:uid, v.presence && URI.join(user.url, v))
    end
  end

  concerning :Url do
    def url
      URI.join(user.url, path).to_s
    end

    def url=(v)
      uri = URI(v)

      self.path = uri.path
      self.user = Pants::User.where(host: uri.host).first_or_initialize

      v
    end

    class_methods do
      def find_by_path_or_previous_path(path)
        where(path: path).take || where("? = ANY (previous_paths)", path).take
      end

      def find_by_url(url)
        uri = URI(url)
        if user = Pants::User.where(host: uri.host).take
          user.documents.find_by_path_or_previous_path(uri.path)
        end
      end

      def for_url(url)
        find_by_url(url) || new(url: url)
      end
    end
  end
end
