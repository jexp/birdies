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
    haml :index
  end

  post '/update' do
    @tags = params["tag"]
    @tags = [@tags] unless @tags.kind_of? Array
    @result = @birds.update(@tags)
    haml :update
  end
end
