require 'rails_helper'

describe Pants::Document do
  context "when saving" do
    subject { build :document }
    let(:other_document) { create :document }
    let(:newest_link) { Pants::Link.newest.take }

    it "automatically populates its outgoing links" do
      subject.html = %[Here's a <a href="#{other_document.url}" class="u-in-reply-to">link</a>!]

      expect { subject.save! }.to change { Pants::Link.count }.by(1)
      expect(newest_link.source).to eq(subject)
      expect(newest_link.target.url).to eq(other_document.url)
    end

    it "correctly detects a.u-in-reply-to replies" do
      subject.html = %[Here's a <a href="#{other_document.url}" class="u-in-reply-to">link</a>!]
      subject.save!
      expect(newest_link.rels).to eq(["reply"])
    end

    it "correctly detects link[rel=in-reply-to] replies" do
      subject.html = %[<link rel="in-reply-to" href="#{other_document.url}">]
      subject.save!
      expect(newest_link.rels).to eq(["reply"])
      expect(other_document.reload.number_of_replies).to eq(1)
    end

    it "correctly detects a.u-like-of likes" do
      subject.html = %[I like <a href="#{other_document.url}" class="u-like-of">this article</a>!]
      subject.save!
      expect(newest_link.rels).to eq(["like"])
      expect(other_document.reload.number_of_likes).to eq(1)
    end

    it "correctly detects a.u-repost-of reposts" do
      subject.html = %[I like <a href="#{other_document.url}"
                       class="u-repost-of">this article</a> so much,
                       I'm reposting it!]
      subject.save!
      expect(newest_link.rels).to eq(["repost"])
      expect(other_document.reload.number_of_reposts).to eq(1)
    end

    it "correctly expands relative URLs" do
      another_document = create(:document, user: subject.user)
      subject.html = %[Here's a <a href="#{another_document.path}" class="u-in-reply-to">link</a>
                       to my own post, because I'm awesome!]
      expect { subject.save! }.to change { Pants::Link.count }.by(1)
      expect(newest_link.rels).to eq(["reply"])
    end

    it "doesn't create multiple Link instances for the same target" do
      subject.html = %[Here's a <a href="#{other_document.url}" class="u-in-reply-to">link</a>,
                       and <a href="#{other_document.url}" class="u-in-reply-to">another link</a>!]
      expect { subject.save! }.to change { Pants::Link.count }.by(1)
    end

    it "doesn't create entries for unknown local targets" do
      subject.html = %[Here's a link to <a href="#{subject.user.url}" class="u-in-reply-to">myself</a>!]
      expect { subject.save! }.to_not change { Pants::Link.count }
    end

    it "doesn't create entries for remote targets" do
      subject.html = %[Here's a link to <a href="http://www.planetcrap.com/" class="u-in-reply-to">a remote site</a>!]

      # We're expecting to send a webmention to the referenced site
      expect(subject).to receive(:send_webmention).with("http://www.planetcrap.com/")

      # We're not expecting local links to change
      expect { subject.save! }.to_not change { Pants::Link.count }
    end

    it "doesn't create links for non-mf2 anchor tags" do
      subject.html = %[Here's a <a href="#{other_document.url}">link</a>!]
      expect { subject.save! }.to_not change { Pants::Link.count }
    end
  end
end
