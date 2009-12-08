#!/usr/bin/env ruby -wKU

require "test/unit"

require "ender/irc_connection/message"

require "mocks/connection"

class Test::Unit::TestCase
  unless const_defined? "TEST_DIR"
    TEST_DIR = File.dirname(__FILE__)

    def self.load_fixtures(type)
      Hash[ *File.read(File.join(TEST_DIR, *%W[fixtures #{type}.txt])).
                  scan(/(\S+)\s+(.+)/).
                  map { |k, v| [k.to_sym, v] }.
                  flatten ]
    end
  
    MESSAGES = load_fixtures("messages")
    
    private
    
    def message(name_or_message)
      Ender::IRCConnection::Message.new( ( name_or_message.is_a?(Symbol) ?
                                           MESSAGES[name_or_message]     :
                                           name_or_message ),
                                         connection )
    end
  end
end
