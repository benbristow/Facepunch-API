#Sinatra dependencies
require 'sinatra'
require 'sinatra/cross_origin'
require "sinatra/multi_route"

#Remember to comment out before deployment!
require 'sinatra/reloader'
require 'pry'

#Parsing stuff
require 'nokogiri'
require 'nokogiri-styles'

require 'open-uri'
require 'json'
require 'sanitize'

set :server, 'webrick'

#Configure CORS for all routes
configure do
  enable :cross_origin
end

ENDPOINT = "http://www.facepunch.com"

# Index page
get '/', '/v1' do
  content_type :json
  { :status => [:online => true, :date => DateTime.now]}.to_json
end

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

get '/v1/user/:uid' do |uid|
  content_type :json
  html = parse_html_from_url("/member.php?u=#{uid}")

  #Check user exists
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
  about = []
  html.css('#view-aboutme dl').each do |info|
    key = info.css('dt').text.strip.gsub(":", "")
    value = info.css('dd').text.strip
    about << {key => value}
  end

  {:data => [
    :id => uid.to_i,
    :name => name,
    :avatar => avatar,
    :title => title,
    :is_gold => is_gold,
    :about => about
  ]}.to_json
end

def parse_html_from_url(path)
  Nokogiri::HTML(open("#{ENDPOINT}#{path}"))
end

def extract_background_image(node)
  begin
    ENDPOINT + node.styles['background-image'][/url\((.+)\)/, 1].gsub("'", '').strip
  rescue
    nil
  end
end

def render_error(message)
  {:success => false, :error => message}.to_json
end