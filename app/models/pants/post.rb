class Pants::Post < ::Post
  def body
    data["body"]
  end

  def body=(v)
    data["body"] = v
  end

  def generate_html
    Formatter.new(body).complete.to_s
  end

  def generate_slug
    body.truncate(20).parameterize
  end
end
