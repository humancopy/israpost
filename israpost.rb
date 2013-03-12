require 'sinatra'
require_relative 'post_rate'

get '/' do  
  "Goto https://github.com/mjnissim/israpost for more info."
end

get '/get-rate' do
  r = PostRate.new(params)
  r.to_json
end

error do
  env['sinatra.error'].name + env['sinatra.error'].message
end