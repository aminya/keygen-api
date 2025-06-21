# frozen_string_literal: true

# Register parameter parser for JSON API mime-type to transform param keys from
# camel case to snake case
ActionDispatch::Request.parameter_parsers[:json]    =
ActionDispatch::Request.parameter_parsers[:jsonapi] = -> raw_post {
  data = ActiveSupport::JSON.decode(raw_post)
  data = { data: data } unless
    data.is_a?(Hash)

  # Transform keys but preserve case and slashes in metadata
  data.deep_transform_keys! do |k|
    # Don't transform metadata keys to preserve case and slashes
    if k.to_s == 'metadata' || k.to_s == 'attributes' && data[k]&.key?('metadata')
      k.to_s
    else
      k.to_s.underscore.parameterize(separator: '_')
    end
  end

  # Handle nested metadata within attributes
  if data[:attributes]&.key?(:metadata)
    data[:attributes][:metadata] = data[:attributes][:metadata].deep_transform_keys { |k| k.to_s }
  end

  data.with_indifferent_access
}

JSONAPI::Rails.configure do |config|
  logger       = Logger.new(STDOUT)
  logger.level = Logger::WARN

  # Dynamic serializer class resolver
  config.jsonapi_class  = -> klass { "#{klass}Serializer".safe_constantize }
  config.jsonapi_object = nil
  config.logger         = logger
end
