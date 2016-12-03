require_relative 'post_rate'

class Israpost < Sinatra::Application

  CURRENCY_CODE               = 'EUR'
  CURRENCY_RATE               = 4.20
  FREE_SHIPPING_FROM          = ENV['FREE_SHIPPING_FROM'].to_f
  FREE_EXPRESS_SHIPPING_FROM  = ENV['FREE_EXPRESS_SHIPPING_FROM'].to_f
  ALLOW_FREE_SHIPPING         = ENV['ALLOW_FREE_SHIPPING'].downcase == 'true'
  ALLOW_FREE_EXPRESS_SHIPPING = ENV['ALLOW_FREE_EXPRESS_SHIPPING'].downcase == 'true'
  SHIPPING_METHODS            = {es: ['AIR', 'EMS'], il: 'EMS'}
  SHIPPING_METHODS_NAMES      = {'AIR' => 'Registered Airmail', 'EMS' => 'Speed Post'}
  EXTRA_GRAMS                 = 50

  use ExceptionNotification::Rack,
    email: {
      email_prefix: "[ISRAPOST] ",
      sender_address: %{"notifier" <notifier@symbolika.com>},
      exception_recipients: %w{webmaster@symbolika.com},
      domain: 'symbolika.com',
      delivery_method: :smtp,
      smtp_settings: { address: 'smtp.mandrillapp.com', port: 587, user_name: 'webmaster@symbolika.com', password: 'i9C2Femm5Cx5NnyF3SMj6A' }
    } unless ENV['RACK_ENV'] == 'development'

  def ship_price(base_price)
    (base_price.round(2).to_f*100).to_i
  end
  def il_ship_price(base_price)
    ship_price(base_price / CURRENCY_RATE)
  end
  def es_ship_price(base_price)
    ship_price(base_price)
  end
  def ship_date(days)
    (DateTime.now + days).strftime('%Y-%m-%d %H:%M:%S %z')
  end
  def poster?(data)
    !data['rate']['items'].detect { |item| item['sku'] =~ /^D-PRNT/i }.blank?
  end
  def sku_base(sku)
    sku.split('-')[0..1].join('-')
  end
  def big_package?(data)
    skus = data['rate']['items'].collect { |item| sku_base(item['sku']) }
    jackets_skus = /(M|W)-(SWSH|HJKT)/
    total_items = data['rate']['items'].inject(0) { |mem, item| mem + item['quantity'].to_i }
    (skus & jackets_skus).present? && ( # an order with jackets
      total_items > 7 || # more than 7 items
      (skus.include?('A-BLTB') && total_items > 2) || # belt bag with more than 2 items
      (data['rate']['items'].inject(0) { |mem,item| mem + (item['sku'].match(jackets_skus) ? item['quantity'].to_i : 0) } > 1) # atleast 2 jackets
    )
  end
  def allow_regular?
    total_weight < 2000 && !poster?(data) && !big_package?(data)
  end
  def data
    @data ||= ::MultiJson.decode(request.body)
  end
  def post_rate(items)
    PostRate.new({ country: data['rate']['destination']['country'], weight: calculate_weight(items) })
  end
  def total_weight(items = nil)
    @total_weight ||= calculate_weight(data['rate']['items'])
  end
  def calculate_weight(items)
    items.inject(EXTRA_GRAMS) { |mem, item| mem + (item['requires_shipping'] ? item['grams'].to_i*item['quantity'].to_i : 0) }
  end
  def cart_total
    @cart_total ||= calculate_total(data['rate']['items'])
  end
  def calculate_total(items)
    items.inject(0) { |mem, item| mem + (item['price'].to_i * item['quantity'].to_i) } / 100
  end
  def free_shipping?
    ALLOW_FREE_SHIPPING && shipping_locations[:es] && shipping_locations[:es][:total] >= FREE_SHIPPING_FROM
  end
  def free_express_shipping?
    ALLOW_FREE_EXPRESS_SHIPPING && shipping_locations[:es] && shipping_locations[:es][:total] >= FREE_EXPRESS_SHIPPING_FROM
  end
  def delivery_time(location, rate_name)
    minimum, maximum = shipping_locations[location][:rates]["#{rate_name}_delivery_time"].split('..').collect(&:to_i)
    {minimum: ship_date(minimum.days), maximum: ship_date(maximum.days)}
  end
  def create_rate(location, rate_name, name, code = nil)
    price_method        = "#{location}_ship_price".to_sym
    allow_free_shipping = (code == 'AIR' && free_shipping?) || (code == 'CUI' && free_express_shipping?)
    if !shipping_locations[location][:rates][rate_name].to_f.zero? || (allow_free_shipping && code == 'AIR')
      delivery_estimate = delivery_time(location, rate_name)
      code ||= rate_name.upcase
      {
        service_name:      name,
        service_code:      code,
        total_price:       allow_free_shipping ? 0 : self.send(price_method, shipping_locations[location][:rates][rate_name]),
        currency:          CURRENCY_CODE,
        min_delivery_date: delivery_estimate[:minimum],
        max_delivery_date: delivery_estimate[:maximum]
      }
    end
  end
  def shipping_locations
    @shipping_locations ||= begin
      locations = data['rate']['items'].inject({}) do |mem, item|
        location = item['sku'] =~ /^D-PRNT/i ? :il : :es
        mem[location] ||= {weight: 0, total: 0, items: []}
        mem[location][:items] << item
        mem
      end

      locations.each do |(key, location)|
        location[:weight]    = calculate_weight(location[:items])
        location[:total]     = calculate_total(location[:items])
        location[:post_rate] = post_rate(location[:items])
        location[:rates]     = ::MultiJson.decode(location[:post_rate].to_json)
      end
    end
  end

  def il_rates
    @il_rates ||= begin
      rates = []

      unless shipping_locations[:il].blank?
        # ISRAEL POST RATES
        # add registered airmail
        # rates << {
        #   service_name: "Registered Airmail",
        #   service_code: "AIR",
        #   total_price: il_ship_price(post_rates['airmail']),
        #   currency: CURRENCY_CODE,
        #   min_delivery_date: ship_date(9.days),
        #   max_delivery_date: ship_date(29.days)
        # } if allow_regular?

        # add eco post
        # rates << {
        #   service_name: "Express Post",
        #   service_code: "ECO",
        #   total_price: il_ship_price(post_rates['eco']),
        #   currency: CURRENCY_CODE,
        #   min_delivery_date: ship_date(7.days),
        #   max_delivery_date: ship_date(11.days)
        # } unless (post_rates['eco'] || 0).zero?

        # add speed post
        rates << create_rate(:il, 'ems', 'Poster Delivery by Speed Post')
      end

      rates.compact
    end
  end

  def es_rates
    @es_rates ||= begin
      rates = []

      unless shipping_locations[:es].blank?
        # add normal airmail
        # rates << {
        #   service_name: "Airmail",
        #   service_code: "STD",
        #   total_price: es_ship_price(post_rates['carta']),
        #   currency: CURRENCY_CODE,
        #   min_delivery_date: ship_date(9.days),
        #   max_delivery_date: ship_date(29.days)
        # } if allow_regular?

        # add registered airmail
        # rates << create_rate(:es, 'carta', (free_shipping? ? 'FREE ' : '') + 'Registered Airmail', 'AIR') # if allow_regular?
        rates << create_rate(:es, 'carta_certificada', (free_shipping? ? 'FREE ' : '') + 'Registered Airmail', 'AIR') # if allow_regular?

        # add express post
        cui_rate = create_rate(:es, 'cui', 'Express Post', 'CUI')
        rates << create_rate(:es, 'cui', 'Express Post', 'CUI')

        # add speed post
        rates << create_rate(:es, 'carta_certificada_urgente', 'Speed Post', 'EMS') unless cui_rate # Only if no CUI

        # add paquetes
        rates << create_rate(:es, 'paquete_prioritario', 'Speed Post', 'EMS')

        if data['rate']['destination']['country'] == 'ES' && data['rate']['destination']['province'] == 'PM'
          rates << {
            service_name:      'Self pickup at Sant Joan',
            service_code:      'SELF',
            total_price:       0,
            currency:          CURRENCY_CODE,
            min_delivery_date: '',
            max_delivery_date: ''
          }
        end
      end

      rates.compact
    end
  end

  get '/' do
    "Goto https://github.com/humancopy/shopify-israpost for more info."
  end
  post '/rates' do
    rates = []
    if il_rates.present? && es_rates.present?
      regular_rate = es_rates.detect { |x| x[:service_code] == 'AIR' }
      if regular_rate
        regular_rate[:service_name] = "#{regular_rate[:service_name]} for Apparel & Accesories, #{il_rates.first[:service_name]}"
        regular_rate[:total_price]  = il_rates.first[:total_price]
      end
    end
    (es_rates + il_rates).each do |rate|
      my_rate = rates.detect { |x| x[:service_code] == rate[:service_code] }
      if my_rate
        my_rate[:total_price] += rate[:total_price]
      else
        rates << rate
      end
    end
    json rates: rates
  end

  get '/create' do
    shop_url = "https://#{ENV['API_KEY']}:#{ENV['PASSWORD']}@#{ENV['SHOP_NAME']}.myshopify.com/admin"
    ShopifyAPI::Base.site = shop_url

    ShopifyAPI::CarrierService.all.collect(&:destroy)

    [
      {
        name: 'israeli post',
        callback_url: "https://shopify-israpost#{'-dev' if ENV['RACK_ENV'] == 'staging'}.herokuapp.com/rates",
        service_discovery: true,
        carrier_service_type: 'api',
        format: 'json'
      }
    ].select { |service| !ShopifyAPI::CarrierService.create(service) }.any? ? "problem :(" : "done ;)"
  end

end

# error do
#   env['sinatra.error'].name + env['sinatra.error'].message
# end
