class BeforeDeleteEventArgs < EventArgs
  attr_reader :session
  attr_reader :document_id
  attr_reader :entity

  def initialize(session, document_id, entity)
    @session = session
    @document_id = document_id
    @entity = entity
  end

  def document_metadata
    @document_metadata |= @session.metadata_for(entity)
  end
end
