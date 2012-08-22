require 'rubygems'
require 'neography'
require 'uri'
require 'twitter'
require 'json'
require 'birds'

def poll_async(tag_names)
    birds = Birds::Birds.new
    Thread.new do
    	while true
      		begin 
    			tags = (tag_names||"").split(", *")
    			tags = ["neo4j"] if tags.empty?
      			res = birds.update(tags)
            puts "Imported #{tags.inspect}: #{res}"
      		rescue => e
        		puts e
      		end
    		sleep 30
    	end
    end
end
