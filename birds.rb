require 'rubygems'
require 'neography'
require 'uri'
require 'twitter'
require 'json'
require 'rest-client'

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

module Birds


  class Birds
    include Neography
    def initialize
      @root = Node.load(0)
      @tags = Node.obtain({:category => 'TAGS' }, {"category" => [:category] })
      @root.outgoing(:TAGS) << @tags unless @root.rel?(:outgoing, :TAGS)
      @users = Node.obtain({:category => 'USERS' }, {"category" => [:category] })
      @root.outgoing(:USERS) << @users unless @root.rel?(:outgoing, :USERS)
    end


    def add_tweet(item)
      id = item.id_str
      twid = item.from_user.downcase
      text = item.text
      puts "Processing \"#{text}\""
      if Node.find("tweets",:id, id)
        puts "Duplicate"
        return false
      end
      short = text.gsub(/(@\w+|https?\S+|#\w+)/,"")[0..30]
      tweet = Node.create_and_index({ :id => id, :date => Time.parse(item.created_at).to_i, :text => text,  :short => short, :link => "http://twitter.com/#{item.from_user}/statuses/#{id}" }, {"tweets" => [:id]})

      user = Node.obtain({ :twid => twid }, {"users" => [:twid]})
      @users.outgoing(:USER) << user if @users.rels(:USER).outgoing.to_other(user).empty?
      user.outgoing(:TWEETED) << tweet

      tokens = text.gsub(/(@\w+|https?\S+|#\w+)/).each do |t|
        if t =~ /^@.+/
          t = t[1..-1].downcase
          other = Node.find("users",:twid,t)
          unless other
            other = Node.create_and_index({ :twid => t }, {"users" => [:twid]})
          end
          user.outgoing(:KNOWS) << other if !(twid.eql?(t)) && user.rels(:KNOWS).outgoing.to_other(other).empty?
          tweet.outgoing(:MENTIONS) << other 
        end
        if t =~ /https?:.+/
          link = Node.obtain({ :url => t }, {"links" => [:url]}) 
          tweet.outgoing(:LINKS) << link
        end
        if t =~ /#.+/
          t = t[1..-1].downcase
          tag = Node.find("tags",:name,t)
          unless tag
            tag = Node.create_and_index({ :name => t }, {"tags" => [:name]})
            @tags.outgoing(:TAGS) << tag            
          end
          tweet.outgoing(:TAGGED) << tag
          user.outgoing(:USED) << tag if user.rels(:USED).outgoing.to_other(tag).empty?
        end
      end
    true
  end 

  def sg_info(twids)
    return {} if twids.nil? || twids.empty?
    params = twids[0..49].collect { |twid| "http://twitter.com/#{twid}" }
    response = RestClient.get "http://socialgraph.apis.google.com/lookup?q=#{params.join(',')}&edo=1&callback=?"
    return {} unless response.code == 200
    nodes = JSON.parse(response.to_str)['nodes']
    result = params.collect do |p| 
      info = nodes[p]
      next [] unless info
      contacts = info['nodes_referenced']
      following = contacts.collect { |uri,type| uri =~ /http:\/\/twitter.com\/(\w+)/ && $1 }.find_all{ |v| v }
      p =~ /http:\/\/twitter.com\/(\w+)/
      [ $1, {'bio' => info['attributes']['bio'], 'follows' => following }]
    end
    Hash[result].merge(sg_info(twids[50..-1]))
  end

  def obtain_user(twid)
    other = Node.find("users",:twid,twid)
    return other if other
    other = Node.create_and_index({ :twid => twid }, {"users" => [:twid]})
    @users.outgoing(:USER) << other
    other
  end

  # todo rewrite to sg_user_info and sg_followers for a list of users
  def update_users(users)
    to_update = Hash[users.collect{ |u| u.bio ? false : [u.twid, u] }.find_all{ |v| v }]
    info = sg_info(to_update.keys)
    to_update.each do |user_twid, user|
      my_info = info[user_twid]
      next unless my_info
      user.bio = my_info['bio']
      followers = Hash[user.outgoing(:FOLLOWS).collect { | u | [u.twid,1] }]
      my_info['follows'].each do |twid|
        next if followers[twid] || user_twid.eql?(twid)
        other = Node.obtain({ :twid => twid }, {"users" => [:twid]})
        user.outgoing(:FOLLOWS) << other
        followers[twid]=1
      end
      puts user_twid
    end
    to_update.keys
  end

  def user(id)
    Node.find("users",:twid, id)
  end
  def tag(id)
    Node.find("tags",:name, id)
  end
  
  def users
     @users.outgoing(:USER)
  end

  def tags
     @tags.outgoing(:TAGS)
  end
  
  def update(tags)
    search = Twitter::Search.new
    puts tags.inspect
    tags.each { |tag| search.hashtag(tag) }
    result = []
    all_new = true
    while all_new
      results = search.collect
      all_new = !results.empty? && results.all? { | item | add_tweet(item) && result << item }
      search.fetch_next_page
    end
    result
  end

  end
end
