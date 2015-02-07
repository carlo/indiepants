class WebmentionsController < ApplicationController
  protect_from_forgery except: [:create]

  def create
    @source = params.require(:source)
    @target = params.require(:target)

    render text: "OK", status: 202

    Thread.new do
      process_webmention(@source, @target)
    end
  end

private

  def process_webmention(source, target)
    # check if target is on this domain
    return false unless URI(target).host == current_site.host

    # fetch source document
    doc = HTTParty.get(source)

    # test if source document actually links to target
    # extract microformat data from source document
    # store webmention
  end
end
