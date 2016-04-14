require 'sinatra'
require 'sinatra/partial'
require 'sinatra/reloader' if development?

require 'redis'

configure do
    redisUri = ENV["REDISTOGO_URL"] || 'redis://localhost:6379'
    uri = URI.parse(redisUri) 
    $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

get '/' do
    content_type :json

    { :result => "success", :msg => "hello from ClassDB v1.0" }.to_json
end

not_found do
    { :result => "error", :msg => "url not found" }.to_json
end

# code 200 = success
# code 300 = invalid params
# code 301 = email already registered
# code 302 = error, read reason

# add new chat message
get '/db/set/' do
    content_type :json

    if params[:key] && params[:value]
        if $redis.get( params[:key] )
            data = { :result => "error", :code => "200", :msg => "that key already exists" }
            JSONP data
        else
            $redis.set( params[:key], params[:value] )
            
            data = { :result => "success", :code => "200", :key => "#{params[:key]}", :value => "#{params[:value]}" }
            JSONP data
        end
    else
        { :result => "error", :code => "300", :msg => "*shrug*" }.to_json
    end
end

# request new chats
get '/db/get/' do
    content_type :json

    if params[:key]
        if $redis.get( params[:key] )
            value = $redis.get( params[:key] )
            data = { :result => "success", :code => "200", :value => value }
            JSONP data
        else
            data = { :result => "error", :code => "200", :msg => "that key doesn't exist" }
            JSONP data
        end
    else
        { :result => "error", :code => "300", :msg => "*shrug*" }.to_json
    end
end