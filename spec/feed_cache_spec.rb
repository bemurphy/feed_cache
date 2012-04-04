require 'spec_helper'
require 'active_support'

# Examples are unforunately coupled to FeedZirra for now because it uses curb which is tough
# to mock, and the state of other feed parsers isn't compliant with our gemset

describe FeedCache do
  let(:blog_url) { "http://blog.kajabi.com/rss.xml" }
  let(:blog_feed) { YAML.load_file(File.join File.dirname(__FILE__), "./fixtures/blog_feed.yaml") }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  def stub_feedzirra
    Feedzirra::Feed.stub(:fetch_and_parse).with(blog_url).and_return(blog_feed)
  end

  def unstub_feedzirra
    begin
      Feedzirra::Feed.unstub(:fetch_and_parse)
    rescue RSpec::Mocks::MockExpectationError => e
      $stderr.puts e.message
    end
  end

  before do
    FeedCache.configure do |fc|
      fc.cache = cache
    end
  end

  after { unstub_feedzirra }

  describe "fetching a feed" do
    before { stub_feedzirra }

    context "for a valid feed grab" do
      it "returns the feed with entries" do
        feed = FeedCache.fetch(blog_url)
        feed.entries.length.should == 20
      end

      it "stores the feed lookup in the cache" do
        cache.exist?(blog_url).should be_false
        FeedCache.fetch(blog_url)
        cache.exist?(blog_url).should be_true
      end
    end

    context "for an invalid feed grab" do
      it "returns nil" do
        Feedzirra::Feed.stub(:fetch_and_parse).with(blog_url).and_return(404)
        FeedCache.fetch(blog_url).should be_nil
      end
    end
  end

  describe "getting just the entries for a feed" do
    before { stub_feedzirra }

    context "for a valid feed grab" do
      it "returns the entries array" do
        FeedCache.entries_for(blog_url).length.should == 10
      end

      it "takes a limit option to trucate entries" do
        FeedCache.entries_for(blog_url, :limit => 3).length.should == 3
      end

      it "respects the default entries limit setting" do
        FeedCache.default_entries_limit = 7
        FeedCache.entries_for(blog_url).length.should == 7
      end
    end

    context "for an invalid feed grab" do
      it "returns an empty array" do
        Feedzirra::Feed.stub(:fetch_and_parse).with(blog_url).and_return(404)
        FeedCache.entries_for(blog_url).should == []
      end
    end

    # There's a bug where TypeError is raised, but I can't replicated it
    # by using FakeWeb, so I want to cover it with an explicit raise for now
    context "for a feed that raises TypeError when fetching entries" do
      let(:no_entry_feed_url) { "http://example.com/no_entry_feed.xml" }
      let(:no_entry_feed) { File.read(File.join(File.dirname(__FILE__), "./fixtures/no_entry_feed.xml")) }

      it "raises FeedCache::MissingEntries" do
        Feedzirra::Feed.stub(:fetch_and_parse).and_raise(TypeError)
        lambda {
          FeedCache.entries_for(no_entry_feed_url)
        }.should raise_error(FeedCache::MissingEntries)
      end
    end
  end
end
