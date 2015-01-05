require_relative 'post_rate'

# SHOP_NAME = 'symbolika'
# API_KEY   = 'e7e376621828b493967d7eb86e1cc5ba'
# PASSWORD  = '87531ea3fed8cf32bd8bcdd526c65176'
SHOP_NAME = 'symbolika-dev'
API_KEY  = 'c3300985faee6c64562e5c46406a3a8f'
PASSWORD = '79b6b3e1c31eb1868fcfbeece019c265'

HANDLING_PRICE = 12 # in ILS
CURRENCY_CODE  = 'EUR'
CURRENCY_RATE  = 4.7

helpers do
  def parsed_body
    ::MultiJson.decode(request.body)
  end
  def price(base_price)
    ((base_price + HANDLING_PRICE) / CURRENCY_RATE).round(2)
  end
end

get '/' do
  "Goto https://github.com/mjnissim/israpost for more info."
end

post '/get-rate' do
  data = parsed_body
  weight = data['rate']['items'].inject(0) { |mem, item| mem + item['grams'] }
  r = PostRate.new({ country: data['rate']['destination']['country'], weight: weight })

  rates = ::MultiJson.decode(r.to_json)

  json :rates => [
      {
        service_name: "7-21 days registered mail",
        service_code: "AIR",
        total_price: price(rates['airmail']),
        currency: CURRENCY_CODE,
        min_delivery_date: DateTime.now + 7.days,
        max_delivery_date: DateTime.now + 21.days
      },
      {
        service_name: "3-5 days speed post",
        service_code: "EMS",
        total_price: price(rates['ems']),
        currency: CURRENCY_CODE,
        min_delivery_date: DateTime.now + 3.days,
        max_delivery_date: DateTime.now + 5.days
      }
    ]
end

get '/add-service' do
  shop_url = "https://#{API_KEY}:#{PASSWORD}@#{SHOP_NAME}.myshopify.com/admin"
  ShopifyAPI::Base.site = shop_url

  success  = 0
  services = [
    {
      name: 'israeli post',
      callback_url: 'http://shopify-israpost.heroku.com/air',
      service_discovery: true,
      format: 'json'
    }
  ]
  services.each do |service|
    new_service = ShopifyAPI::CarrierService.create(service)
    new_service.name              = service[:name]
    new_service.callback_url      = service[:callback_url]
    new_service.service_discovery = service[:service_discovery]
    new_service.format            = service[:format]
    logger.info "new_service = #{new_service.inspect}"
    success = success + 1 if new_service.save
  end
  success == new_services.count ? "done ;)" : "problem :("
end

error do
  env['sinatra.error'].name + env['sinatra.error'].message
end