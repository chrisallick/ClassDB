require 'sinatra'
require 'sinatra/partial'
require 'sinatra/reloader' if development?

require 'redis'

configure do
    redisUri = ENV["REDISTOGO_URL"] || 'redis://localhost:6379'
    uri = URI.parse(redisUri) 
    $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

    if $redis.get("chaaaat_user_count")
        $redis.set("chaaaat_user_count", $redis.get("chaaaat_user_count") )
    else
        $redis.set("chaaaat_user_count", 0 )
    end

    if $redis.get("chaaaat_chat_count")
        $redis.set("chaaaat_chat_count", $redis.get("chaaaat_chat_count") )
    else
        $redis.set("chaaaat_chat_count", 0 )
    end
end

get '/' do
    content_type :json

    { :result => "success", :msg => "hello v1.0" }.to_json
end

not_found do
  { :result => "error", :msg => "url not found" }.to_json
end

# code 200 = success
# code 300 = invalid params
# code 301 = email already registered
# code 302 = error, read reason

# master look up list?
chaaaat_user_list =  [
    "tiff.hockin@gmail.com",
    "chrisallick@gmail.com"
]

emails = '{
    "Christopher Peter Allick": "chrisallick@gmail.com",
    "Tiff Hockin": "tiff.hockin@gmail.com"
}'

emails_json = JSON.parse( emails )

get '/loadusers/' do
    content_type :json

    emails_json.each do |key, value|
        if !$redis.exists( "chaaaat_user:#{value}" )
            $redis.incr( "chaaaat_user_count" )
            uid = $redis.get("chaaaat_user_count")

            new_user = {
                "email" => value,
                "name" => key,
                "uid" => uid
            }

            $redis.set( "chaaaat_user:#{uid}", new_user.to_json )
            $redis.set( "chaaaat_user:#{value}", uid )
            $redis.lpush( "chaaaat_users", uid )

            puts "added"
        else
            puts "exists"
        end
    end

    { :result => "success", :msg => "loaded users" }.to_json
end

# add your email and photo
post '/users/user/new/' do
    content_type :json

    if params[:email]
        puts params[:email]

        puts $redis.exists( "chaaaat_user:#{params[:email]}" )

        if !chaaaat_user_list.include? params[:email]
            { :result => "error", :code => "301", :msg => "invalid user" }.to_json
        elsif $redis.exists( "chaaaat_user:#{params[:email]}" )
            uid = $redis.get("chaaaat_user:#{params[:email]}")
            user_object = JSON.parse($redis.get("chaaaat_user:#{uid}"))
            
            { :result => "success", :code => "200", :msg => "registered", :user => user_object }.to_json
        else
            $redis.incr( "chaaaat_user_count" )
            uid = $redis.get("chaaaat_user_count")

            new_user = {
                "email" => params[:email],
                "name" => emails_json.key(params[:email]),
                "uid" => uid
            }

            $redis.set( "chaaaat_user:#{uid}", new_user.to_json )
            $redis.set( "chaaaat_user:#{params[:email]}", uid )
            $redis.lpush( "chaaaat_users", uid )

            { :result => "success", :code => "200", :msg => "registered", :user => new_user }.to_json
        end
    else
        # return error invalid params
        { :result => "error", :code => "300", :msg => "*shrug*" }.to_json
    end
end

# add new chat message
post '/chat/new/' do
    content_type :json

    if params[:email] && params[:msg]
        puts "#{params[:email]} said: #{params[:msg]}"

        $redis.incr( "chaaaat_chat_count" )
        cid = $redis.get("chaaaat_chat_count")
        new_chat = {
            "email" => params[:email],
            "msg" => params[:msg],
            "inits" => params[:inits],
            "time" => $redis.time[0],
            "cid" => cid
        }
        $redis.set( "chaaaat_chat:#{cid}", new_chat.to_json )
        $redis.lpush( "chaaaat_chats", cid )
        
        { :result => "success", :code => "200", :chat => new_chat }.to_json
    else
        { :result => "error", :code => "300", :msg => "*shrug*" }.to_json
    end
end

# request new chats
# send your index and get new chats.
get '/chat/new/' do
    content_type :json

    if params[:email] && params[:index]
        puts "#{params[:email]} current index: #{params[:index]}"
        
        chats = []
        all = $redis.lrange("chaaaat_chats", 0, $redis.llen( "chaaaat_chats" ) )
        all.each do |cid|
            chat_object = JSON.parse($redis.get("chaaaat_chat:#{cid}"))

            chats.push( chat_object )
        end

        chats.reverse!

        { :result => "success", :code => "200", :chats => chats }.to_json
    else
        { :result => "error", :code => "300", :msg => "*shrug*" }.to_json
    end
end




