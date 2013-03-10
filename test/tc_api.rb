require "net/http"
require "uri"
require 'json' # I think I'll call my next son "JSON" (and my girl, Ruby).

# address = "http://localhost:4567/get-rate?country=japa&weight=80"
address = "http://israpost.herokuapp.com/get-rate?country=japan&weight=80"

uri = URI.parse(address)

response = Net::HTTP.get_response(uri)

if response.code.to_i==200
  puts JSON.load(response.body).collect {|k,v| "#{k} => #{v}\n" }
else
  puts "Error, code #{response.code}."
  puts response.body
end

