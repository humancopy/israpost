require 'yaml'
require 'json'

class PostRate
  attr_reader :weight
  
  @@delivery_methods = %w[airmail air_parcel ems]

  def initialize(args={})
    # load YAMLs to hashes
    @@countries = self.class.load_yaml 'yaml/countries.yml' unless defined?(@@countries)
    @@airmail_rates = self.class.load_yaml 'yaml/airmail.yml' unless defined?(@@airmail_rates)
    @@ems_rates = self.class.load_yaml 'yaml/ems.yml' unless defined?(@@ems_rates)
    unless defined?(@@air_parcel_rates)
      @@air_parcel_rates = self.class.load_yaml 'yaml/air_parcel.yml'
    end
    
    self.weight = args[:weight]
    self.parcel = args[:parcel]
    self.country = args[:country] if args[:country]
    self.delivery_method = args[:delivery_method] if args[:delivery_method]
  end

  def weight=(amount) @weight = amount.to_i end
  def cost ; get_rate_for(delivery_method) end
  
  def country ; name_calculated if @country_details end
  
  def country=(name)
    hash = @@countries.select do |k,v|
      [ v["name_calculated"],   v["official_name_english"], 
        v["israel_post_name"],  v["code"],
      ].include?(name.to_s.upcase)
      end.values.first
    raise "Invalid country \"#{name}\"." if not hash
    @country_details = hash
  end

  def delivery_method
    return @delivery_method if @delivery_method
    # If it's a parcel you can't send it as regular airmail:
    dm = @@delivery_methods.reject{|m|m=="airmail" if parcel}
    # Now get the cheapest delivery method:
    h = Hash[ dm.collect{|m|[get_rate_for(m), m]} ]
    h[h.keys.sort.first]
  end
  
  def delivery_method=(name)
    name == "" ? name = nil : name =  name.to_s.downcase
    if name.nil? or @@delivery_methods.member?(name)
      @delivery_method = name
    else
      raise "No such delivery method."
    end
  end
  
  def parcel ; @parcel.nil? ? weight>2000 : @parcel end
  alias :parcel? :parcel
  
  def parcel=(value)
    @parcel = case
    when ["1", 1, true, "true", "t"].member?(value) then true
    when ["false", "0", 0, false, "f"].member?(value) then false
    when ["", nil].member?(value) then nil
    end
  end
  
  def to_json
    { country: country, weight: weight, cost: cost, delivery_method: delivery_method,
      parcel: parcel?, official_name_english: official_name_english,
      israel_post_name: israel_post_name, country_code: code,
      airmail: airmail, air_parcel: air_parcel, ems: ems, common_name: common_name,
      airmail_group: airmail_group, air_parcel_group: air_parcel_group,
      ems_group: ems_group
    }.to_json
  end

private
  def method_missing(method)
    # Capture repetitive methods for country info
    if %w[  airmail_group ems_group
            name_calculated israel_post_name
            air_parcel_group appear_in_shipping_list
            code common_name official_name_english].member?(method.to_s)
      country_details[method.to_s]
    elsif @@delivery_methods.member?(method.to_s)
      get_rate_for method.to_s
    else
      raise NoMethodError.new ("No method '#{method}'.")
    end
  end

  def country_details; @country_details || raise("Invalid country \"#{name}\".") end

  def get_rate_for(name)
    rates = eval("@@#{name}_rates[#{name}_group]")
    additions = eval("@@#{name}_rates")["additions"]
    weight_limit = eval("@@#{name}_rates")["weight_limit"]
    max_priced_weight = rates.select{|k,v|k.is_a?(Range)}.collect{|k,v|k.max}.last
    if weight <= max_priced_weight
      rate = rates.select{|k,v|k===weight}.values.first
    elsif weight > weight_limit
      rate = nil
    else
      max = rates.select{|k,v|k===max_priced_weight}.values.first
      add = (((weight-(max_priced_weight+1)) / additions) + 1) * rates["addition"]
      rate = max + add
    end
    return rate
  end
  
  def self.load_yaml(name)
    YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)), name))
  end
end
