module ApplicationHelper
  def clean_html(source)
    Formatter.new(source).sanitize.to_s.html_safe
  end
end
