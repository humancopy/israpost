require 'yaml'
require 'json'

class PostRate
  def initialize(args={})
    # load YAMLs to hashes
    @@countries        = self.class.load_yaml 'yaml/countries.yml'  unless defined?(@@countries)
    @@ems_rates        = self.class.load_yaml 'yaml/ems.yml'        unless defined?(@@ems_rates)
    @@airmail_rates    = self.class.load_yaml 'yaml/airmail.yml'    unless defined?(@@airmail_rates)
    @@eco_rates        = self.class.load_yaml 'yaml/eco.yml'        unless defined?(@@eco_rates)
    @@air_parcel_rates = self.class.load_yaml 'yaml/air_parcel.yml' unless defined?(@@air_parcel_rates)

    @@carta_rates                     = self.class.load_yaml 'yaml/carta.yml'                     unless defined?(@@carta_rates)
    @@carta_certificada_rates         = self.class.load_yaml 'yaml/carta_certificada.yml'         unless defined?(@@carta_certificada_rates)
    @@carta_urgente_rates             = self.class.load_yaml 'yaml/carta_urgente.yml'             unless defined?(@@carta_urgente_rates)
    @@carta_certificada_urgente_rates = self.class.load_yaml 'yaml/carta_certificada_urgente.yml' unless defined?(@@carta_certificada_urgente_rates)

    self.attributes = args
  end

  def attributes=(args) args.each { |name, value| self.send(:"#{name}=", value) } end
  def cost ; get_rate_for(delivery_method) end
  def weight ; @weight.to_i end
  def weight=(amount) amount.to_i<=0 ? raise(InvalidWeight) : @weight = amount.to_i end

  def country ; name_calculated if @country_details end
  def country_details; @country_details || raise(InvalidCountry) end

  def country=(name)
    hash = @@countries.select do |v|
      [ v["name_calculated"],   v["official_name_english"],
        v["israel_post_name"],  v["country_code"],
      ].include?(name.to_s.upcase)
      end.first
    raise InvalidCountry.new(name) if not hash
    @country_details = hash
  end

  def delivery_method
    return @delivery_method if @delivery_method
    # If it's a parcel you can't send it as regular airmail:
    dm = @@delivery_methods.reject{|m|m=="airmail" if parcel}
    # Now get the cheapest delivery method:
    h = Hash[ dm.collect{|m|[get_rate_for(m), m]} ]
    h[h.keys.compact.sort.first] || 0
  end

  def delivery_method=(name)
    name == "" ? name = nil : name =  name.to_s.downcase
    if name.nil? or @@delivery_methods.member?(name)
      @delivery_method = name
    else
      raise InvalidDeliveryMethod
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
    meths = @@country_detail_fields.collect(&:to_sym)
    meths = meths + @@delivery_methods.collect(&:to_sym) + @@delivery_time_methods.collect(&:to_sym)
    # Reject setter methods, question mark methods, and the name of this method itself:
    meths = meths | self.class.instance_methods(false).reject{
        |m| m.to_s[-1,1]=="=" or m.to_s[-1,1]=="?" or m.to_sym==__method__}
    # Create a hash with the method names and results, and convert to JSON.
    Hash[meths.collect{|m|[m.to_s, self.send(m.intern)]}].to_json
  end

private
  def method_missing(method)
    # Capture repetitive methods for country info
    if @@country_detail_fields.member?(method.to_s)
      country_details[method.to_s]
    elsif @@delivery_methods.member?(method.to_s)
      get_rate_for method.to_s
    elsif @@delivery_time_methods.member?(method.to_s)
      get_delivery_time_for method.to_s
    else
      raise NoMethodError.new("No method '#{method}'.")
    end
  end

  def get_rate_for(name)
    rates_for    = self.class.send(:class_variable_get, :"@@#{name}_rates")
    rates        = rates_for[self.send(:"#{name}_group")]
    additions    = rates_for["additions"]
    weight_limit = rates_for["weight_limit"]
    return 0 if rates.nil?
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
    if rates["discount"]
      discount_percentage = rates["discount"].to_f
      discount_amount = (discount_percentage/100)*rate
      rate -= discount_amount
    end
    return rate.round(1) + (rates_for['handling'] || 0).to_f if rate
  end

  def get_delivery_time_for(name)
    attr_name = name.to_s.sub(/_delivery_time$/, '')
    rates_for = self.class.send(:class_variable_get, :"@@#{attr_name}_rates")
    rates     = rates_for[self.send(:"#{attr_name}_group")]
    rates['delivery_time'] if rates
  end

  def self.load_yaml(name)
    YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)), name))
  end

  @@delivery_time_methods = %w[ ems_delivery_time carta_delivery_time carta_certificada_delivery_time carta_urgente_delivery_time carta_certificada_urgente_delivery_time ]
  @@delivery_methods = %w[ airmail air_parcel eco ems carta carta_certificada carta_urgente carta_certificada_urgente ]
  @@country_detail_fields = %w[ airmail_group ems_group eco_group carta_group carta_certificada_group carta_urgente_group carta_certificada_urgente_group name_calculated israel_post_name
                                air_parcel_group appear_in_shipping_list country_code
                                common_name official_name_english]


end

class InvalidWeight < StandardError; end
class InvalidDeliveryMethod < StandardError; end

class InvalidCountry < StandardError
  def initialize(name = nil)
    super "No such country '#{name}'"
  end
end

