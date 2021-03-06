#Sinatra dependencies
require 'sinatra'
require 'sinatra/cross_origin'
require "sinatra/multi_route"

require 'sinatra/reloader'
require 'pry'

#Parsing stuff
require 'nokogiri'
require 'nokogiri-styles'

require 'open-uri'
require 'httparty'
require 'json'
require 'sanitize'

set :server, 'webrick'

#Forbidden error fix?
set :protection, :except => :json_csrf

#Configure CORS for all routes
configure do
  enable :cross_origin
  set :server, 'thin'
end

ENDPOINT = "http://www.facepunch.com"

# Index page
get '/', '/v1' do
  content_type :json
  { :status => [:online => true, :date => DateTime.now]}.to_json
end

#Get list of Forums
get '/v1/forums' do
  content_type :json

  forums = []
  html = parse_html_from_url("/")

  html.css('.forumbit_post').each do |fb|
    id = fb.css('.forumtitle a').attr('href').value[/\d+/].to_i
    title = fb.css('.forumtitle a').text
    image = extract_background_image(fb.css('td.foruminfo')[0])
    viewing = fb.css('span.viewing').text[/\d+/].to_i
    description = fb.css('p.forumdescription').text

    begin
      last_post_date = fb.css('p.lastpostdate').text.strip
      last_post_thread_id = fb.css('p.lastposttitle > a')[0].attr('href')[/\d+/].to_i
      last_post_thread_title = fb.css('p.lastposttitle').text.strip

      last_post_user_id = fb.css('div.LastPostAvatar a')[0].attr('href')[/\d+/].to_i
      last_post_user_avatar = extract_background_image(fb.css('div.LastPostAvatar')[0])
      last_post_user_name = fb.css('div.LastPostAvatar img')[0].attr('alt')
    rescue NoMethodError
    end

    #Push to results array
    forums << {
      :id => id, :title => title, :description => description, :image => image, :viewing => viewing,
      :last_post => {
        :date => last_post_date,
        :thread => { :id => last_post_thread_id, :title => last_post_thread_title },
        :user => {:id => last_post_user_id, :name => last_post_user_name, :avatar => last_post_user_avatar}}
    }
  end

  { :data => forums }.to_json
end

#Get Threads in Forum
get '/v1/forums/:fid' do |fid|
  content_type :json

  #Page parameter
  page = "1"
  if(params.has_key?("page"))
    page = params["page"].to_i
  end

  html = parse_html_from_url("/forumdisplay.php?f=#{fid}&page=#{page}&order=desc")

  forum_title = html.css('title').text

  threads = []
  html.css('tr.threadbit').each do |tb|
    id = tb.attr('id')[/\d+/].to_i
    title = tb.css('h3.threadtitle > a').text.strip
    replies = tb.css('td.threadreplies > a').text.to_i
    views = tb.css('td.threadviews > span').text.to_i
    viewers = tb.css('div.threadmeta > div.author > span.viewers').text[/\d+/].to_i
    is_sticky = tb.classes.include?('sticky')
    icon = "#{ENDPOINT}/" + tb.css('td.threadicon > img').attr('src')
    icon.sub!('com//', 'com/')

    last_page = 1
    if(tb.css('span.threadpagenav > a').length > 0)
      last_page = tb.css('span.threadpagenav > a').last.text.sub('Last', '').to_i
    end

    #Ratings
    ratings = []
    tb.css('div.threadratings > span').each do |r|
      rating_icon = r.css('img').attr('src')
      rating_name = r.css('img').attr('alt')
      rating_count = r.css('strong')[0].text.to_i
      ratings << {:name => rating_name, :icon => rating_icon, :count => rating_count}
    end

    #OP
    op_name = tb.css('div.threadmeta > div.author > a').text.strip
    op_id = tb.css('div.threadmeta > div.author > a')[0].attr('href')[/\d+/].to_i
    op = {:id => op_id, :name => op_name}

    #Last Poster
    lastpost_date = tb.css('td.threadlastpost > dl > dd')[0].text
    lastpost_user_name = tb.css('td.threadlastpost a')[0].text.strip
    lastpost_user_id = tb.css('td.threadlastpost a')[0].attr('href')[/\d+/].to_i
    last_post = {:date => lastpost_date, :user => {:id => lastpost_user_id, :name => lastpost_user_name}}

    threads << {
      :id => id, :title => title, :is_sticky => is_sticky, :icon => icon,
      :replies => replies, :views => views, :viewers => viewers, :ratings => ratings, :op => op, :last_post => last_post, :last_page => last_page
    }
  end

  if(threads.length > 0)
    forum = {:id => fid.to_i, :page => page.to_i, :title => forum_title, :threads => threads }
    { :data => forum }.to_json
  else
    return render_error("Invalid forum/Can't get threads from forum")
  end
end

#Get User Info
get '/v1/users/:uid' do |uid|
  content_type :json
  html = parse_html_from_url("/member.php?u=#{uid}")

  if(html.css('.standard_error').length > 0)
    return render_error("User does not exist")
  end

  #General info
  name = html.css('span#userinfo > span')[0].text.strip
  title = html.css('.usertitle').text
  avatar = "#{ENDPOINT}/" + html.css('img#user_avatar').attr('src')

  begin
    is_gold = html.css('#userinfo font')[0].attr('color') == "#A06000"
  rescue NoMethodError
    is_gold = false
  end

  #About Me
  about = {}
  html.css('#view-aboutme dl').each do |info|
    key = info.css('dt').text.strip.gsub(":", "").downcase.gsub(" ", "_")
    value = info.css('dd').text.strip
    about[key] = value
  end

  user = {
    :id => uid.to_i, :name => name, :avatar => avatar, :title => title, :is_gold => is_gold, :about => about
  }

  {:data => user}.to_json
end

# Get thread

get '/v1/threads/:tid' do |tid|
  content_type :json

  page = "1"
  if(params.has_key?("page"))
    page = params["page"]
  end

  html = parse_html_from_url("/showthread.php?t=#{tid}&page=#{page}")

  #Get meta info
  thread_title = html.css('title').text
  thread_id = tid.to_i
  page = page.to_i

  #Get Posts
  posts = []

  post_elements = html.css('ol#posts > li')

  post_elements.each do |pelement|
    begin
      #Get Poster info
      poster_name = pelement.css('div.username_container').text.strip
      poster_id = pelement.css('div.username_container a').first.attr('href')[/\d+/].to_i
      poster_avatar = "#{ENDPOINT}/" + pelement.css('img.avatar_image').attr('src')
      poster = {:id => poster_id, :name => poster_name, :avatar => poster_avatar}

      #Get Post Info
      post_date = pelement.css('span.date').text
      post_id = pelement.css('span.nodecontrols a').first.attr('name')[/\d+/].to_i

      #Get Body, Strip Out Quotes
      post_body = pelement.css('blockquote.postcontent').first
      post_body.css('div.quote').each do |quote|
        quote.remove
      end
      post_body = post_body.inner_html.strip

      #Get Ratings
      post_ratings = []

      post_rating_elements = pelement.css('span.rating_results > span')
      post_rating_elements.each do |relement|
        rating_name = relement.css('img').attr('alt')
        rating_image = "#{ENDPOINT}/" + relement.css('img').attr('src')
        rating_count = relement.css('strong').text.to_i
        rating = {:name => rating_name, :image => rating_image, :count => rating_count}
        post_ratings << rating
      end

      post = {:id => post_id, :body => post_body, :date => post_date, :ratings => post_ratings, :poster => poster}
      posts << post
    rescue
    end
  end


  thread = {:id => thread_id, :title => thread_title, :page => page, :posts => posts}
  {:data => thread}.to_json

end

private

#Parse HTML from URL with Nokogiri and return Nokogiri object
def parse_html_from_url(path)
  doc = HTTParty.get("#{ENDPOINT}#{path}")
  Nokogiri::HTML(doc)
end

#Extract background image from inline styles.
def extract_background_image(node)
  begin
    ENDPOINT + node.styles['background-image'][/url\((.+)\)/, 1].gsub("'", '').strip
  rescue
    nil
  end
end

#Render error message
def render_error(message)
  {:success => false, :error => message}.to_json
end
