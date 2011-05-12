require 'rubygems'
require 'sinatra/base'
require 'uri'
require 'birds'

class App < Sinatra::Base
  set :haml, :format => :html5 
  set :app_file, __FILE__

  include Birds

  before do
    @birds = Birds.new
  end

  get '/' do
    erb :index
  end

  get '/users' do
    content_type :json
    @birds.users.collect{ |u| { :name => "@"+u.twid, :link => "/user/#{u.twid}", :value => u.outgoing(:TWEETED).size }}.to_json
  end

  get '/user/:id' do |id|
    # user with :KNOWS, :TWEETED, :USED
    @user = @birds.user(id) # sunburst, social graph
    erb :user
  end

  get '/tag/:id' do |id|
    @tag = @birds.tag(id)
    erb :tag
  end

  get '/admin/tweettime' do
    @birds.users.each { |u| u.outgoing(:TWEETED).each { |t| t.date = Time.parse(t.date).to_i if t.date.kind_of? String }}
    "Updated tweets"
  end
  
  get '/admin/update' do
    @birds.update_users(@birds.users).inspect
  end
  
  get '/info/:twids' do |twids|
    @birds.sg_info(twids.split(',')).inspect
  end

  get '/tags' do
    content_type :json
    @birds.tags.collect{ |t| { :name => "#"+t.name, :link => "/tag/#{t.name}", :value => t.incoming(:TAGGED).size } }.to_json
  end

  post '/update' do
    tag = @params["tag"]
    @tags = []
    if tag.kind_of? Array
      @tags + tag
    else
      @tags << tag
    end
    @tags << "neo4j" unless @tags.include? "neo4j"
    @added = @birds.update(@tags)
    redirect "/"
  end
end
