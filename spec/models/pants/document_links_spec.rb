require 'rails_helper'

describe Pants::Document do
  context "when saving" do
    subject { build :document }

    it "automatically populates its outgoing links" do
      stub_request(:get, "http://www.planetcrap.com/").
         to_return(status: 200, body: "<html><head><title>PlanetCrap!</title></head><body></body></html>", headers: {})

      subject.html = %[Here's a <a href="http://www.planetcrap.com/" rel="foo">link</a>!]

      expect { subject.save! }.to change { Pants::Link.count }.by(1)
      link = Pants::Link.newest.take
      expect(link.source).to eq(subject)
      expect(link.target.url).to eq("http://www.planetcrap.com/")
      expect(link.rel).to eq("foo")
    end

    it "doesn't create entries for unknown local targets" do
      subject.html = %[Here's a link to <a href="#{subject.user.url}">myself</a>!]
      expect { subject.save! }.to_not change { Pants::Link.count }
    end
  end
end
