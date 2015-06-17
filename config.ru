#\ -p 9331

require 'rubygems'
require 'bundler'

Bundler.require

require './app.rb'

run Sinatra::Application