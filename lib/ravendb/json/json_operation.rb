class JsonOperation
  # TODO: move to constants
  COLLECTION = "@collection".freeze
  PROJECTION = "@projection".freeze
  KEY = "@metadata".freeze
  ID = "@id".freeze
  CONFLICT = "@conflict".freeze
  ID_PROPERTY = "Id".freeze
  FLAGS = "@flags".freeze
  ATTACHMENTS = "@attachments".freeze
  INDEX_SCORE = "@index-score".freeze
  LAST_MODIFIED = "@last-modified".freeze
  RAVEN_JAVA_TYPE = "Raven-Java-Type".freeze
  CHANGE_VECTOR = "@change-vector".freeze
  EXPIRES = "@expires".freeze

  def self.entity_changed(new_obj, document_info, changes)
    doc_changes = (changes.nil? ? nil : [])
    if !document_info.new_document? && !document_info.document.nil?
      return compare_json(document_info.id, document_info.document["entity"], new_obj, changes, doc_changes)
    end
    return true if changes.nil?
    new_change(nil, nil, nil, doc_changes, documents_changes.change_type.document_added)
    changes.put(document_info.id, doc_changes)
    true
  end

  def self.compare_json(id, original_json, new_json, changes, doc_changes)
    return true unless original_json
    new_json_props = new_json.keys
    old_json_props = original_json.keys
    new_fields = (new_json_props - old_json_props)
    removed_fields = (old_json_props - new_json_props)
    removed_fields.each do |field|
      return true if changes.nil?
      new_change(field, nil, nil, doc_changes, :removed_field)
    end
    new_json_props.each do |prop|
      next if [LAST_MODIFIED, COLLECTION, CHANGE_VECTOR, ID].include?(prop)
      if new_fields.include?(prop)
        return true if changes.nil?
        new_change(prop, new_json.get(prop), nil, doc_changes, :new_field)
        next
      end
      new_prop = new_json[prop]
      old_prop = original_json[prop]
      case new_prop
      when Integer, TrueClass, FalseClass, String
        break if new_prop == old_prop || compare_values(old_prop, new_prop)
        return true if changes.nil?
        new_change(prop, new_prop, old_prop, doc_changes, :field_changed)
        break
      when NilClass
        break if old_prop.null?
        return true if changes.nil?
        new_change(prop, nil, old_prop, doc_changes, :field_changed)
        break
      when Array
        if old_prop.nil? || !old_prop.is_a?(ArrayNode)
          return true if changes.nil?
          new_change(prop, new_prop, old_prop, doc_changes, :field_changed)
          break
        end
        changed = compare_json_array(id, old_prop, new_prop, changes, doc_changes, prop)
        return true if changes.nil? && changed
        break
      when Hash
        if old_prop.nil? || old_prop.null?
          return true if changes.nil?
          new_change(prop, new_prop, nil, doc_changes, :field_changed)
          break
        end
        changed = compare_json(id, old_prop, new_prop, changes, doc_changes)
        return true if changes.nil? && changed
        break
      else
        raise ArgumentError
      end
    end
    return false if changes.nil? || doc_changes.empty?
    changes[id] = doc_changes
    true
  end
end
