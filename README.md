# israpost

Israel Post shipping rates class and API. Made with Ruby, YAML and Sinatra (no DB).

## How to use the online API

To see how it works before you try it in Ruby code, go to this link:

http://israpost.herokuapp.com/get-rate?country=usa&weight=7500&delivery_method=ems&parcel=false

Now, here's how to do it in Ruby.

```ruby
require "net/http"
require "uri"
require 'json'

# I think I'll call my next son "JSON" (and my girl Ruby).

# This is the address of the API:
address = "http://israpost.herokuapp.com/get-rate"

# Set your parameters, especially country and weight.
params = {:country=>"japan", :weight=>350}

uri = URI.parse(address)
uri.query = URI.encode_www_form(params)
response = Net::HTTP.get_response(uri)

if response.code.to_i==200 # i.e. it's OK
  my_hash = JSON.load(response.body)
else
  puts "Error, code #{response.code}."
  puts response.body
end
```

The kind of response you'll get is something like this:

```ruby
puts my_hash.collect {|k,v| "#{k} => #{v}\n" }
# airmail_group => 3
# ems_group => 5
# name_calculated => JAPAN
# israel_post_name => יפן 
# air_parcel_group => 3
# appear_in_shipping_list => 1
# country_code => JP
# common_name => 
# official_name_english => JAPAN
# airmail => 14.9
# air_parcel => 89.5
# ems => 91.0
# cost => 14.9
# weight => 350
# country => JAPAN
# delivery_method => airmail
# parcel => false
```

What you usually need to look for is ```cost```. **isralpost** always picks the cheapest airmail method and throws it into ```cost```.

### Other Options

Basically, if you've got the weight and country you're sending to, you're safe. But there might be other options you'll want to set.

```ruby
:parcel => true
:parcel => false
```

Unless otherwise stated, any weight above 2,000 grams will be considered a parcel. However, there might be cases where your postman does not consider a small (but heavy) package as a parcel because it's got small dimensions; and vice versa - he might consider it a parcel, even though it's light, because it's a large box. So the ```parcel``` option should be set manually to override default assumptions.

```ruby
:delivery_method => "ems"
:delivery_method => "airmail"
:delivery_method => "air_parcel"
```

**israpost** will always pick the cheapest airmail delivery method for you, based on other options you set. If you know specifically that you would like your package sent via "EMS" (Express Mail Service) then you can set that option manually. In some cases, EMS can be cheaper than the normal air_parcel method.

