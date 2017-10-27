require 'date'
require "database/exceptions"

module RavenDB
  class DateUtil
    def self.stringify(datetime)
      invalid_date_message = 'Invalid parameter passed to RavenDB'\
        '::DateUtil::stringify. It should be instance of DateTime'

      raise InvalidOperationException, invalid_date_message unless datetime.is_a?(DateTime)

      return datetime.strftime("%Y%m%dT%H%M%S%6N0")
    end
  end
end