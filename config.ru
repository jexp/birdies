$LOAD_PATH.unshift File.dirname(__FILE__), File.dirname(__FILE__)+"/lib"

puts $LOAD_PATH

require 'rubygems'
require 'bundler'
require 'neography'

Bundler.require

Neography::Config.server = ENV['NEO4J_HOST'] || 'localhost'
Neography::Config.port =  (ENV['NEO4J_PORT'] || "7474").to_i
Neography::Config.authentication = 'basic'
Neography::Config.username = ENV['NEO4J_LOGIN']
Neography::Config.password = ENV['NEO4J_PASSWORD']


require 'poll_async'

poll_async(ENV["TWITTER_TAGS"])

require 'app'

run App

