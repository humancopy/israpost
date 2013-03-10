require 'sinatra'
require_relative 'post_rate'

get '/' do  
  "Hello, World!"
end

get '/get-rate' do
  r = PostRate.new(params)
  r.to_json
end

error do
  env['sinatra.error'].name + env['sinatra.error'].message
end