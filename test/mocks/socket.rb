#!/usr/bin/env ruby -wKU

require "singleton"

class MockSocket
  include Singleton
  
  def new(host, port)
    @host                = host
    @port                = port
    @sent_to_server      = Array.new
    
    self
  end
  
  attr_reader   :host, :port, :sent_to_server
  attr_accessor :deliver_from_server
  
  def print(line)
    @sent_to_server << line
  end
  
  def gets
    @deliver_from_server.shift
  end
  
  def closed?
    false
  end
end

class Ender::IRCConnection
  TCPSocket = MockSocket.instance unless const_defined? "TCPSocket"
end

class Test::Unit::TestCase
  private
  
  def socket
    MockSocket.instance
  end
end
