module ApplicationHelper
  def clean_html(source)
    Formatter.new(source).sanitize.to_s.html_safe
  end

  def render_post_form(form)
    render "#{form.object.type.gsub('.', '/').tableize}/form", form: form, post: form.object
  rescue ActionView::MissingTemplate
    content_tag(:p) { "No form found for this post type." }
  end
end
