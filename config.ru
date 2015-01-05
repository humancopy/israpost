require 'rubygems'
require 'bundler'

Bundler.require

require 'active_support/core_ext'
require 'sinatra/json'

require './israpost'
run Sinatra::Application
