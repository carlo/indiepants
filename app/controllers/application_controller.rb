class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_filter :ensure_current_site

  def ensure_current_site
    redirect_to :pants_setup unless current_site.present?
  end

  def render_404
    if request.format.html?
      render template: 'application/render_404', status: 404
    else
      render text: "not found",
        status: 404,
        content_type: 'text/plain'
    end
  end

  concerning :CurrentSite do
    included do
      helper_method :current_site
    end

    def current_site
      @current_site ||= Pants::User.where(host: request.host).take
    end
  end

  concerning :CurrentUser do
    included do
      helper_method :current_user, :logged_in?, :logged_out?
    end

    def logged_in?
      current_user.present? && current_user == current_site
    end

    def logged_out?
      !logged_in?
    end

    def current_user
      @current_user ||= load_current_user
    end

    def load_current_user
      current_user_id = session[:current_user_id]
      if current_user_id
        Pants::User.where(id: current_user_id).take || logout_user
      end
    end

    def login_user(user)
      session[:current_user_id] = user.id
    end

    def logout_user
      session[:current_user_id] = nil
    end

    def ensure_logged_in!
      unless logged_in?
        redirect_to :pants_login, alert: "You must be logged in to access this page."
      end
    end

    def ensure_logged_out!
      raise "No access" if logged_in?
    end
  end

private

  def serve_custom_css!
    @serve_custom_css = true
  end
end
