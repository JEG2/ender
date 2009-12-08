#!/usr/bin/env ruby -wKU

require "singleton"

class MockConnection
  include Singleton
  
  def initialize
    @sent_messages = Array.new
  end
  
  attr_reader :sent_messages
  
  def nick
    "ender_bot"
  end
  
  def send_message(to, message)
    @sent_messages << "PRIVMSG #{to} :#{message}\r\n"
  end
end

class Test::Unit::TestCase
  private
  
  def connection
    MockConnection.instance
  end
end
