require 'observer'

module Observable
  def emit(event, data = nil)
    notify_observers(event, data)
  end
  
  def on(event, &listener)
    add_observer(RavenDB::EventListener.new(event, listener))
  end  
end 

module RavenDB
  class EventListener
    def initialize(event, &listener)
      @event = event
      @listener = listener
    end  

    def update(event, data = nil)
      if @event == event
        @listener.call(data)
      end  
    end
  end 
end 