require 'ostruct'
require 'set'

module ForemanAzureRm
  class AzureShapeTranslator
    # --- Inbound: ARM REST JSON → SDK-compatible OpenStruct ---

    INBOUND_KEY_FIXES = {
      'disk_size_g_b' => 'disk_size_gb',
      'public_i_p_address' => 'public_ipaddress',
      'public_i_p_allocation_method' => 'public_ipallocation_method',
      'private_i_p_address' => 'private_ipaddress',
      'private_i_p_allocation_method' => 'private_ipallocation_method',
    }.freeze

    def normalize_response(data)
      case data
      when Hash then deep_to_ostruct(normalize_inbound(data))
      when Array then data.map { |item| normalize_response(item) }
      else data
      end
    end

    # --- Outbound: SDK-shaped OpenStruct → ARM REST JSON string ---

    OUTBOUND_KEY_MAP = {
      'public_ipallocation_method' => 'publicIPAllocationMethod',
      'private_ipallocation_method' => 'privateIPAllocationMethod',
      'public_ipaddress' => 'publicIPAddress',
      'private_ipaddress' => 'privateIPAddress',
      'disk_size_gb' => 'diskSizeGB',
      'virtual_machine_extension_type' => 'type',
      'ip_configurations' => 'ipConfigurations',
      'ip_address' => 'ipAddress',
    }.freeze

    ARM_TOP_LEVEL_FIELDS = %w[location tags name id plan sku zones identity kind].freeze

    SUB_RESOURCE_ARRAYS = Set.new(%w[ipConfigurations networkInterfaces]).freeze

    def serialize_request(body)
      case body
      when String then body
      when OpenStruct then arm_serialize(body.to_h).to_json
      when Hash then arm_serialize(body).to_json
      else body.to_json
      end
    end

    private

    # -- Inbound internals --

    def normalize_inbound(hash)
      h = underscore_keys(hash)
      flatten_and_enrich(h)
    end

    def underscore_keys(hash)
      hash.each_with_object({}) do |(k, v), result|
        new_key = k.to_s.underscore
        new_key = INBOUND_KEY_FIXES[new_key] || new_key
        result[new_key] = case v
                          when Hash then underscore_keys(v)
                          when Array then v.map { |item| item.is_a?(Hash) ? underscore_keys(item) : item }
                          else v
                          end
      end
    end

    def flatten_and_enrich(hash)
      hash = hash.merge(hash.delete('properties')) if hash.key?('properties') && hash['properties'].is_a?(Hash)
      id = hash['id']
      if id.is_a?(String) && id.include?('/resourceGroups/')
        parts = id.split('/')
        rg_index = parts.index { |p| p.casecmp?('resourceGroups') }
        hash['resource_group'] = parts[rg_index + 1] if rg_index
      end
      hash.transform_values do |v|
        case v
        when Hash then flatten_and_enrich(v)
        when Array then v.map { |item| item.is_a?(Hash) ? flatten_and_enrich(item) : item }
        else v
        end
      end
    end

    def deep_to_ostruct(hash)
      converted = hash.transform_values do |v|
        case v
        when Hash then deep_to_ostruct(v)
        when Array then v.map { |item| item.is_a?(Hash) ? deep_to_ostruct(item) : item }
        else v
        end
      end
      OpenStruct.new(converted)
    end

    # -- Outbound internals --

    def arm_serialize(hash)
      camelized = arm_camelize(hash)
      wrap_in_properties(camelized)
    end

    def arm_camelize(hash)
      hash.each_with_object({}) do |(k, v), result|
        key_s = k.to_s
        new_key = OUTBOUND_KEY_MAP[key_s] || key_s.camelize(:lower)
        result[new_key] = if SUB_RESOURCE_ARRAYS.include?(new_key) && v.is_a?(Array)
                            v.map { |item| wrap_in_properties(arm_camelize_value(item)) }
                          else
                            arm_camelize_value(v)
                          end
      end
    end

    def arm_camelize_value(v)
      case v
      when Hash then arm_camelize(v)
      when OpenStruct then arm_camelize(v.to_h)
      when Array then v.map { |item| arm_camelize_value(item) }
      else v
      end
    end

    def wrap_in_properties(hash)
      return hash unless hash.is_a?(Hash)
      top = {}
      props = {}
      hash.each do |k, v|
        if ARM_TOP_LEVEL_FIELDS.include?(k)
          top[k] = v
        else
          props[k] = v
        end
      end
      top['properties'] = props unless props.empty?
      top
    end
  end
end
