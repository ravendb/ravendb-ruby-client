require 'date'
require "database/exceptions"

module RavenDB
  class DateUtil
    PARSE_FORMAT = "%Y-%m-%dT%H:%M:%S.%N"
    STRINGIFY_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N0"

    def self.stringify(datetime)
      invalid_date_message = 'Invalid parameter passed to RavenDB'\
        '::DateUtil::stringify. It should be instance of DateTime'

      raise InvalidOperationException, invalid_date_message unless datetime.is_a?(DateTime)

      datetime.strftime(STRINGIFY_FORMAT)
    end

    def self.parse(datestring)
      if datestring.end_with?("Z")
        datestring = datestring.chomp("Z")
      end

      DateTime.strptime(datestring, PARSE_FORMAT)
    end

    def self.zero_date
      DateTime.new(1, 1, 1, 0, 0, 0)
    end
  end
end