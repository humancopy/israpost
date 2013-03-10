israpost
========

Israel Post shipping rates class and API.

How to use API
--------------

```ruby
require "net/http"
require "uri"
require 'json'

# I think I'll call my next son "JSON" (and my girl Ruby).

address = "http://israpost.herokuapp.com/get-rate"
params = {:country=>"japan", :weight=>350}
uri = URI.parse(address)
uri.query = URI.encode_www_form(params)
response = Net::HTTP.get_response(uri)

if response.code.to_i==200
  my_hash = JSON.load(response.body)
  puts my_hash.collect {|k,v| "#{k} => #{v}\n" }
else
  puts "Error, code #{response.code}."
  puts response.body
end
```

