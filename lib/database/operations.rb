require 'database/exceptions'

class AbstractOperation
  def get_command(conventions)
    raise NotImplementedError, 'You should implement get_command method'
  end
end

class Operation < AbstractOperation
  def get_command(conventions, store = nil)
    raise NotImplementedError, 'You should implement get_command method'
  end
end

class AdminOperation < AbstractOperation
end  

class ServerOperation < AbstractOperation
end  

class PatchResultOperation < Operation 
end  