require 'sinatra'
require 'sinatra/partial'
require 'sinatra/reloader' if development?

require 'redis'

configure do
    redisUri = ENV["REDISTOGO_URL"] || 'redis://localhost:6379'
    uri = URI.parse(redisUri) 
    $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    if $redis.get("classchat_count")
        $redis.set("classchat_count", $redis.get("classchat_count") )
    else
        $redis.set("classchat_count", 0 )
    end
end

get '/' do
    content_type :json

    { :result => "success", :msg => "hello from classchat v1.0" }.to_json
end

not_found do
    { :result => "error", :msg => "url not found" }.to_json
end

# code 200 = success
# code 300 = invalid params
# code 301 = email already registered
# code 302 = error, read reason

# add new chat message
get '/chat/new/' do
    content_type :json

    if params[:username] && params[:text]
        $redis.incr( "classchat_count" )
        cid = $redis.get("classchat_count")
        
        new_chat = {
            "username" => params[:username],
            "text" => params[:text],
            "time" => $redis.time[0],
            "cid" => cid
        }

        $redis.set( "classchat_chat:#{cid}", new_chat.to_json )
        $redis.lpush( "classchat_chats", cid )

        $redis.ltrim( "classchat_chats", 0, 100 )
        
        data = { :result => "success", :code => "200", :newchat => new_chat }
        JSONP data
    else
        { :result => "error", :code => "300", :msg => "*shrug*" }.to_json
    end
end

get '/chat/clear/' do
    content_type :json

    $redis.del("classchat_chats")

    { :result => "success", :code => "200" }.to_json
end

# request new chats
get '/chat/history/' do
    content_type :json

    chats = []
    all = $redis.lrange("classchat_chats", 0, $redis.llen( "classchat_chats" ) )
    all.each do |cid|
        chat_object = JSON.parse($redis.get("classchat_chat:#{cid}"))

        chats.push( chat_object )
    end

    chats.reverse!

    data = { :result => "success", :code => "200", :chats => chats }
    JSONP data
end