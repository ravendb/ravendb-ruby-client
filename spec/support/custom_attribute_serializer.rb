class CustomAttributeSerializer < RavenDB::AttributeSerializer
  def on_serialized(serialized)
    metadata = serialized[:metadata]

    return unless metadata["Raven-Ruby-Type"] == TestCustomSerializer.name

    serialized[:serialized_attribute] = serialized[:original_attribute].camelize(:lower)

    return unless serialized[:original_attribute] == "item_options"

    serialized[:serialized_value] = serialized[:original_value].join(",")
  end

  def on_unserialized(serialized)
    metadata = serialized[:metadata]

    return unless metadata["Raven-Ruby-Type"] == TestCustomSerializer.name

    serialized[:serialized_attribute] = serialized[:original_attribute].underscore

    return unless serialized[:original_attribute] == "itemOptions"

    serialized[:serialized_value] = serialized[:original_value].split(",").map { |option| option.to_i }
  end
end
