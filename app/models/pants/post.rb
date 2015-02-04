class Pants::Post < ::Post
  store_accessor :data, :body

  def generate_html
    Formatter.new(body).complete.to_s
  end

  def generate_slug
    body.truncate(20).parameterize
  end
end
