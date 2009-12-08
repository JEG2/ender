#!/usr/bin/env ruby -wKU

require "test/unit"

require "ender/irc_connection/send_queue"

class TestSendQueue < Test::Unit::TestCase
  def setup
    @queue    = Ender::IRCConnection::SendQueue.new
    @expected = %w[one two three four]
    @queue.enqueue(*@expected)
  end
  
  def test_behaves_as_a_simple_queue
    @expected.each { |message| assert_equal(message, @queue.dequeue) }
    assert_nil(@queue.dequeue)
  end
  
  def test_returns_a_wait_time_when_message_limit_is_exceeded_in_time_frame
    @queue.flooding_time_limit    = 0.1
    @queue.flooding_message_limit = 1
    assert_equal(@expected.shift, @queue.dequeue)
    assert_wait(0.1)
    
    sleep 0.2

    @queue.flooding_message_limit = 2
    2.times { assert_equal(@expected.shift, @queue.dequeue) }
    assert_wait(0.1)
  end
  
  def test_empty_queue_returns_nil_not_a_wait_time
    @queue.flooding_time_limit    = 10
    @queue.flooding_message_limit = @expected.size
    @expected.each { |message| assert_equal(message, @queue.dequeue) }
    assert_nil(@queue.dequeue)
  end
  
  private
  
  def assert_wait(max_wait)
    wait_time = @queue.dequeue
    assert_kind_of(Numeric, wait_time)
    assert( wait_time.between?(0, max_wait),
            "Wait time exceeds flooding limit range" )
  end
end
