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

address = "http://israpost.herokuapp.com/get-rate?country=japan&weight=80"

uri = URI.parse(address)

response = Net::HTTP.get_response(uri)

if response.code.to_i==200 # i.e. OK
  my_hash = JSON.load(response.body)
else
  puts "Error, code #{response.code}."
  puts response.body
end
```

