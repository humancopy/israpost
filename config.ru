require 'rubygems'
require 'bundler'

Bundler.require(:default, ENV['RACK_ENV'] || :development)

Dotenv.load if ENV['RACK_ENV'] == 'development'

require 'active_support/core_ext'
require 'sinatra/json'

require './israpost'
run Israpost
