require_relative 'post_rate'

if ENV['RACK_ENV'] == 'production'
  SHOP_NAME = 'symbolika'
  API_KEY   = 'e7e376621828b493967d7eb86e1cc5ba'
  PASSWORD  = '87531ea3fed8cf32bd8bcdd526c65176'
else
  SHOP_NAME = 'symbolika-dev'
  API_KEY   = 'c3300985faee6c64562e5c46406a3a8f'
  PASSWORD  = '79b6b3e1c31eb1868fcfbeece019c265'
end

HANDLING_PRICE = 14.40 # in ILS
CURRENCY_CODE  = 'EUR'
CURRENCY_RATE  = 4.7

helpers do
  def parsed_body
    ::MultiJson.decode(request.body)
  end
  def ship_price(base_price)
    (((base_price + HANDLING_PRICE) / CURRENCY_RATE).round(2).to_d*100).to_i
  end
  def ship_date(days)
    (DateTime.now + days).strftime('%Y-%m-%d %H:%M:%S %z')
  end
end

get '/' do
  "Goto https://github.com/humancopy/shopify-israpost for more info."
end

post '/rates' do
  data = parsed_body
  weight = data['rate']['items'].inject(0) { |mem, item| mem + (item['grams'].to_i*item['quantity'].to_i) }
  allow_airmail = weight <= 2000 && data['rate']['items'].detect { |item| item['sku'] =~ /^D-PRNT/i }.blank?
  r = PostRate.new({ country: data['rate']['destination']['country'], weight: weight })

  post_rates = ::MultiJson.decode(r.to_json)

  rates = []

  # add registered airmail
  rates << {
    service_name: "Registered Airmail",
    service_code: "AIR",
    total_price: ship_price(post_rates['airmail']),
    currency: CURRENCY_CODE,
    min_delivery_date: ship_date(9.days),
    max_delivery_date: ship_date(29.days)
  } if allow_airmail

  # add speed post
  rates << {
    service_name: "Speed Post",
    service_code: "EMS",
    total_price: ship_price(post_rates['ems']),
    currency: CURRENCY_CODE,
    min_delivery_date: ship_date(3.days),
    max_delivery_date: ship_date(7.days)
  }

  json :rates => rates
end

get '/create' do
  shop_url = "https://#{API_KEY}:#{PASSWORD}@#{SHOP_NAME}.myshopify.com/admin"
  ShopifyAPI::Base.site = shop_url

  ShopifyAPI::CarrierService.all.collect(&:destroy)

  [
    {
      name: 'israeli post',
      callback_url: 'https://shopify-israpost.herokuapp.com/rates',
      service_discovery: true,
      carrier_service_type: 'api',
      format: 'json'
    }
  ].select { |service| !ShopifyAPI::CarrierService.create(service) }.any? ? "problem :(" : "done ;)"
end

error do
  env['sinatra.error'].name + env['sinatra.error'].message
end