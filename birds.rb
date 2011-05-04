require 'rubygems'
require 'neography'
require 'rest-client'
require 'uri'
require 'feed_tools'
# >> puts search.fetch_next_page.first.inspect
#<#Hashie::Rash created_at="Wed, 04 May 2011 12:31:46 +0000" from_user="jessicakilbride" from_user_id=280017273 from_user_id_str="280017273" geo=nil id=65755494752583680 id_str="65755494752583680" iso_language_code="de" metadata=<#Hashie::Rash result_type="recent"> profile_image_url="http://a2.twimg.com/profile_images/1331420611/image_normal.jpg" source="&lt;a href=&quot;http://twitter.com/#!/download/iphone&quot; rel=&quot;nofollow&quot;&gt;Twitter for iPhone&lt;/a&gt;" text="@justinbieber marry me?" to_user="justinbieber" to_user_id=8994366 to_user_id_str="8994366">
# => "<#Hashie::Rash created_at=\"Wed, 04 May 2011 15:58:36 +0000\" from_user=\"christianphang\" from_user_id=3398193 from_user_id_str=\"3398193\" geo=nil id=65807547021524992 id_str=\"65807547021524992\" iso_language_code=\"eo\" metadata=<#Hashie::Rash result_type=\"recent\"> profile_image_url=\"http://a0.twimg.com/profile_images/286951481/cartman-screw-you-guys_normal.jpg\" source=\"&lt;a href=&quot;http://ubersocial.com&quot; rel=&quot;nofollow&quot;&gt;\\303\\234berSocial&lt;/a&gt;\" text=\"Multi Platform: .NET(C#,F#,IronRuby,...) VS JVM(Java,Clojure,JRuby,...) #jaxcon\" to_user_id=nil to_user_id_str=nil>"
# ["from_user_id_str", "profile_image_url", "created_at", "from_user", "id_str", "metadata", "to_user_id", "text", "id", "from_user_id", "geo", "iso_language_code", "to_user_id_str", "source"]
# search.hashtag("jaxcon").result_type("recent").per_page(15).collect
# search.containing("marry me").to("justinbieber").result_type("recent").per_page(3).each
module Neography
  class Node 
    class << self
      def obtain(data, to_index)
        return Node.create_and_index(data,to_index) unless to_index
        to_index.each do |index,names| 
          names.each do | prop |
            node = Node.find(index,prop,data[prop])
            return node if node
          end
        end
        Node.create_and_index(data,to_index)
      end
      
      def create_and_index(data, to_index)
        node = Neography::Node.create(data)
        return node unless to_index
        to_index.each do |index,names| 
          names.each do | prop |
            node.neo_server.add_node_to_index(index,prop,URI.encode(data[prop]),node.neo_id) 
          end
        end
        node
      end
      
      def find(index, prop, value)
        res = Neography::Rest.new.get_node_index(index,prop,URI.encode(value))
        return nil unless res
        Neography::Node.load(res.first)
      end
    end
  end
end

include Neography

neo = Rest.new

@root = Node.load(0)
@tags = Node.obtain({:category => 'TAGS' }, {"category" => [:category] })
@root.outgoing(:TAGS) << @tags unless @root.rel?(:outgoing, :TAGS)
@users = Node.obtain({:category => 'USERS' }, {"category" => [:category] })
@root.outgoing(:USERS) << @users unless @root.rel?(:outgoing, :USERS)

#@tweets = {}

def add_tweet(item)
  id = item.guid.gsub(/http:\/\/twitter.com\/(.+)\/statuses\/(.+)/,'\1:\2')
  puts "Processing #{item.title}"
  if Node.find("tweets",:id, id)
    puts "Duplicate"
    return
  end
  text = item.title
  clean = text.gsub(/(@\w+|https?\S+|#\w+)/,"")
  tweet = Node.obtain({ :id => id, :date => item.published, :text => clean, :raw => text, :link => item.link }, {"tweets" => [:id]})

  twid = item.author.email.gsub(/@twitter.com/,"")
  user = Node.obtain({ :twid => twid, :name => item.author.name }, {"users" => [:twid]})
  user.name = item.author.name unless user.name
  @users.outgoing(:USER) << user if @users.rels(:USER).outgoing.to_other(user).empty?
  user.outgoing(:TWEETED) << tweet
  
  tokens = text.gsub(/(@\w+|https?\S+|#\w+)/).each do |t|
    puts "token #{t}"
    if t =~ /^@.+/
        t = t[1..-1]
        other = Node.obtain({ :twid => t }, {"users" => [:twid]})
        @users.outgoing(:USER) << other if @users.rels(:USER).outgoing.to_other(other).empty?
        user.outgoing(:KNOWS) << other if !(user.eql? other) && user.rels(:KNOWS).outgoing.to_other(other).empty?
        tweet.outgoing(:MENTIONS) << other 
    end
    if t =~ /https?:.+/
      link = Node.obtain({ :url => t }, {"links" => [:url]}) 
      tweet.outgoing(:LINKS) << link
    end
    if t =~ /#.+/
      t = t[1..-1]
      tag = Node.obtain({ :name => t }, {"tags" => [:name]})
      tweet.outgoing(:TAGGED) << tag
      user.outgoing(:USED) << tag
      @tags.outgoing(:TAGS) << tag if @tags.rels(:TAGS).outgoing.to_other(tag).empty?
    end
  end
end 

uri = $ARGV[0] || 'feed://search.twitter.com/search.rss?q=%23jaxcon'
#uri = 'file:///Users/mh/ruby/birds/search.rss'
#uri = 'file:///Users/mh/ruby/birds/test.rss'

while true 
  puts "Fetching #{uri}"
  begin 
    feed = FeedTools::Feed.open( uri ) #feed.title
    feed.items.each { |item| add_tweet(item) }
  rescue => e
    puts e
  end
  sleep 120
end