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
    @users = []
    @used_tags = []
#    @users = @birds.users.collect{ |u| [u.twid, u.outgoing(:TWEETED).size] }.sort { |a,b| b[1] <=> a[1] }
#    @used_tags = @birds.tags.collect{ |t| [t.name, t.incoming(:TAGGED).size] }.sort { |a,b| b[1] <=> a[1] }
    erb :index
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
