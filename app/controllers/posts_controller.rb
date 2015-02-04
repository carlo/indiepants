class PostsController < ApplicationController
  respond_to :html, :json

  def index
    @posts = current_site.posts.latest
    respond_with @posts
  end

  def show
    posts = current_site.posts
    @post = if params[:id]
      posts.find(params[:id])
    else
      date = Date.new(params[:year].to_i, params[:month].to_i, params[:day].to_i)
      posts
        .where(published_at: (date.beginning_of_day)..(date.end_of_day))
        .where(slug: params[:slug]).take!
    end

    # Enforce canonical URL
    if request.format.html? && request.url != @post.url
      return redirect_to(@post.url)
    end

    respond_with @post
  end

  def create
    # A bit of a workaround; if we feed the type to Post.new directly,
    # ActiveRecord apparently doesn't go through .find_sti_class at all.
    #
    klass = Post.find_sti_class(params[:post][:type])

    # Create the post
    @post = klass.create(post_params) do |post|
      post.user = current_site
    end

    respond_with @post, location: @post.url
  end

  def edit
    @post = current_site.posts.find(params[:id])
    respond_with @post
  end

  def update
    @post = current_site.posts.find(params[:id])
    @post.update_attributes(post_params)
    respond_with @post, location: @post.url
  end

private

  def post_params
    params.require(:post).permit(:slug, :body)
  end
end
