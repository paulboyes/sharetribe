require 'spec_helper'

describe Admin::CommunityListingsController, type: :controller do

  before(:all) do
    @community = FactoryGirl.create(:community)
    @user = create_admin_for(@community)

    @category1 = FactoryGirl.create(:category, community: @community)
    @category1.translations << FactoryGirl.create(:category_translation, :name => "Music", :locale => "en", :category => @category1)

    @category2 = FactoryGirl.create(:category, community: @community)
    @category2.translations << FactoryGirl.create(:category_translation, :name => "Books", :locale => "en", :category => @category2)

    @joe = FactoryGirl.create(:person, given_name: 'Joe')
    @joe.accepted_community = @community

    @jack = FactoryGirl.create(:person, given_name: 'Jack')
    @jack.accepted_community = @community

    @listing_joe1 = FactoryGirl.create(:listing, community_id: @community.id, author: @joe, category_id: @category1.id, title: "classic")

    @listing_joe2 = FactoryGirl.create(:listing, community_id: @community.id, author: @joe, category_id: @category1.id, title: "rock")
    @listing_joe2.update(open: 0)

    @listing_joe3 = FactoryGirl.create(:listing, community_id: @community.id, author: @joe, category_id: @category1.id, title: "pop")
    @listing_joe3.valid_until = 100.days.ago
    @listing_joe3.save(validate: false)

    @listing_jack1 = FactoryGirl.create(:listing, community_id: @community.id, author: @jack, category_id: @category2.id, title: "bible")

    @listing_jack2 = FactoryGirl.create(:listing, community_id: @community.id, author: @jack, category_id: @category2.id, title: "encyclopedia")
    @listing_jack2.update(open: false)

    @listing_jack3 = FactoryGirl.create(:listing, community_id: @community.id, author: @jack, category_id: @category2.id, title: "wonderland")
    @listing_jack3.valid_until = 100.days.ago
    @listing_jack3.save(validate: false)

    @all_listings = [
      @listing_joe1, @listing_joe2, @listing_joe3,
      @listing_jack1, @listing_jack2, @listing_jack3,
    ]
  end

  before(:each) do
    @request.host = "#{@community.ident}.lvh.me"
    @request.env[:current_marketplace] = @community
    sign_in_for_spec(@user)
  end

  describe "#index search" do
    it "retrieves all listings in no query given" do
      get :index, params: {community_id: @community.id}
      expect(assigns("listings").size).to eq 6
    end

    it "finds listings by title" do
      @all_listings.each do |listing|
        get :index, params: {community_id: @community.id, q: listing.title}
        listings = assigns("listings")
        expect(listings.size).to eq 1
        expect(listings).to eq [listing]
      end
    end

    it "finds listings by category title" do
      [@category1, @category2].each do |category|
        get :index, params: {community_id: @community.id, q: category.translations.first.name}
        listings = assigns("listings")
        expect(listings.size).to eq 3
        expect(listings.map(&:category_id).uniq).to eq [category.id]
      end
    end

    it "finds listings by author" do
      [@joe, @jack].each do |author|
        get :index, params: {community_id: @community.id, q: author.given_name}
        listings = assigns("listings")
        expect(listings.size).to eq 3
        expect(listings.map(&:author_id).uniq).to eq [author.id]
      end
    end
  end

  describe "#index status filter" do
    it "retrieves all when status not present" do
      get :index, params: {community_id: @community.id, status: []}
      expect(assigns("listings").size).to eq 6

      get :index, params: {community_id: @community.id}
      expect(assigns("listings").size).to eq 6
    end

    it "filters open" do
      get :index, params: {community_id: @community.id, status: ["open"]}
      listings = assigns("listings")
      expect(listings.size).to eq 4
      expect(listings.sort_by(&:id)).to eq [@listing_joe1, @listing_joe3, @listing_jack1, @listing_jack3]
    end

    it "filters closed" do
      get :index, params: {community_id: @community.id, status: ["closed"]}
      listings = assigns("listings")
      expect(listings.size).to eq 2
      expect(listings.sort_by(&:id)).to eq [@listing_joe2, @listing_jack2]
    end

    it "filters expired" do
      get :index, params: {community_id: @community.id, status: ["expired"]}
      listings = assigns("listings")
      expect(listings.size).to eq 2
      expect(listings.sort_by(&:id)).to eq [@listing_joe3, @listing_jack3]
    end

    it "filters open + expired" do
      get :index, params: {community_id: @community.id, status: ["expired", "open"]}
      listings = assigns("listings")
      expect(listings.size).to eq 4
      expect(listings.sort_by(&:id)).to eq [@listing_joe1, @listing_joe3, @listing_jack1, @listing_jack3]
    end

    it "filters closed + expired" do
      get :index, params: {community_id: @community.id, status: ["expired", "closed"]}
      listings = assigns("listings")
      expect(listings.size).to eq 4
      expect(listings.sort_by(&:id)).to eq [@listing_joe2, @listing_joe3, @listing_jack2, @listing_jack3]
    end

    it "applies both filter and query" do
      get :index, params: {community_id: @community.id, status: ["expired", "open"], q: "won"}
      listings = assigns("listings")
      expect(listings.size).to eq 1
      expect(listings).to eq [@listing_jack3]

      get :index, params: {community_id: @community.id, status: ["expired", "open"], q: "p"}
      listings = assigns("listings")
      expect(listings.size).to eq 1
      expect(listings).to eq [@listing_joe3]
    end
  end
end
