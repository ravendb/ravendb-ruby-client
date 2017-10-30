require 'date'
require "database/exceptions"

module RavenDB
  class TypeUtilities
    DATE_PARSE_FORMAT = "%Y-%m-%dT%H:%M:%S.%N"
    DATE_STRINGIFY_FORMAT = "%Y-%m-%dT%H:%M:%S.%6N0"

    BASIC_TYPES = [
        String, Integer, Numeric, Float,
        Numeric, NilClass, Hash, Symbol,
        Array, Range, Date, DateTime
    ]

    def self.is_document?(object)
      object.is_a?(Object) &&
          BASIC_TYPES.all? {|basic_type|
            !object.is_a?(basic_type)
          }
    end

    def self.stringify_date(datetime)
      invalid_date_message = 'Invalid parameter passed to RavenDB'\
        '::TypeUtilities::stringify_date. It should be instance of DateTime'

      raise InvalidOperationException, invalid_date_message unless
          (datetime.is_a?(DateTime) || datetime.is_a?(Date))

      datetime.strftime(DATE_STRINGIFY_FORMAT)
    end

    def self.parse_date(datestring)
      if datestring.end_with?("Z")
        datestring = datestring.chomp("Z")
      end

      DateTime.strptime(datestring, DATE_PARSE_FORMAT)
    end

    def self.zero_date
      DateTime.new(1, 1, 1, 0, 0, 0)
    end
  end
end