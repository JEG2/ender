#!/usr/bin/env ruby -wKU

require "test_helper"

require "ender"

require "mocks/socket"

class TestIRCConnection < Test::Unit::TestCase
  class NamedObject
    def initialize(name)
      @name = name
    end
    
    def to_s
      @name.to_s
    end
  end
  
  def test_new_connection_connects_to_irc
    connection("irc.freenode.net")
    assert_equal("irc.freenode.net", socket.host)
    assert_equal(6667,               socket.port)

    connection("irc.freenode.net", 9999)
    assert_equal("irc.freenode.net", socket.host)
    assert_equal(9999,               socket.port)
  end
  
  def test_login_send_nick_and_user
    connection.login("ender_bot")
    assert_last_queued( [ "NICK ender_bot\r\n",
                          "USER ender_bot 0 * :'ender_bot' IRC Bot\r\n" ] )
  end
  
  def test_login_with_password_ids_to_nickserv
    connection.login("ender_bot", "secret")
    assert_last_queued("PRIVMSG NickServ :IDENTIFY secret\r\n")
  end
  
  def test_login_raises_login_error_on_failure
    connection.login("ender_bot")
    socket.deliver_from_server = MESSAGES.values_at(:nick_in_use)
    assert_raise(Ender::Errors::LoginError) { run_irc(:skip_read_check) }
  end
  
  def test_joining_channels
    connection.join("##textmate")
    assert_last_queued("JOIN ##textmate\r\n")

    connection.join("##textmate", "#botwar")
    assert_last_queued(["JOIN ##textmate\r\n", "JOIN #botwar\r\n"])

    connection.join("#private :password with space!")
    assert_last_queued("JOIN #private :password with space!\r\n")
  end
  
  def test_joining_raises_join_error_on_failure_before_login
    connection.login("ender_bot")
    @connection.join("#highgroove", "#botwar")
    socket.deliver_from_server = MESSAGES.values_at(:joined_channel)
    assert_nothing_raised(Ender::Errors::JoinError) do
      run_irc(:skip_read_check)
    end
    
    socket.deliver_from_server = MESSAGES.values_at(:bad_channel_key)
    assert_raise(Ender::Errors::JoinError) { run_irc(:skip_read_check) }
  end
  
  def test_joining_after_login_doesnt_change_logged_in_status_or_raise_errors
    connection.login("ender_bot")
    run_irc(:skip_read_check)
    assert(@connection.logged_in?, "Connection wasn't logged in")
    
    @connection.join("#highgroove")
    assert(@connection.logged_in?, "Joining doesn't affect login")
    socket.deliver_from_server = MESSAGES.values_at(:bad_channel_key)
    assert_nothing_raised(Ender::Errors::JoinError) do
      run_irc(:skip_read_check)
    end
  end
  
  def test_connection_monitors_login_status
    connection.login("ender_bot")
    assert(!@connection.logged_in?, "Login reported before confirmation")
    @connection.join("#botwar")
    assert(!@connection.logged_in?, "Login reported before confirmation")
    socket.deliver_from_server = MESSAGES.values_at(:welcome)
    run_irc(:skip_read_check)
    assert(!@connection.logged_in?, "Login reported before confirmation")

    socket.deliver_from_server = MESSAGES.values_at(:joined_channel)
    run_irc(:skip_read_check)
    assert(@connection.logged_in?, "Login not detected")
  end
  
  def test_quit
    connection.quit
    assert_last_queued("QUIT\r\n")

    connection.quit("Bye y'all!")
    assert_last_queued("QUIT :Bye y'all!\r\n")
  end
  
  def test_messages_are_queued_on_send
    connection.send_raw "SENT :to queue"
    assert_last_queued("SENT :to queue\r\n")
    assert(socket.sent_to_server.empty?, "Message were sent early")
  end
  
  def test_queued_messages_are_sent_on_run
    connection.send_raw "WILL :hit server"
    assert(socket.sent_to_server.empty?, "Message were sent early")
    run_irc(:skip_read_check)
    assert_nil(@connection.send_queue.dequeue)
    assert_equal("WILL :hit server\r\n", socket.sent_to_server.last)
  end
  
  def test_sending_raw_content_to_irc
    connection.send_raw "SENT exactly :as is"
    assert_last_queued("SENT exactly :as is\r\n")
  end
  
  def test_sending_messages
    connection.send_message(NamedObject.new("##textmate"), "Hi channel!")
    assert_last_queued("PRIVMSG ##textmate :Hi channel!\r\n")

    connection.send_message(NamedObject.new("JEG2"), "Hi James!")
    assert_last_queued("PRIVMSG JEG2 :Hi James!\r\n")
  end
  
  def test_sending_a_notice
    connection.send_notice(NamedObject.new("JEG2"), "You have 5 notes.")
    assert_last_queued("NOTICE JEG2 :You have 5 notes.\r\n")
  end
  
  def test_a_handler_for_all_messages
    connection.handle_messages do |message|
      assert_equal(@expected.shift, message.raw)
      read_to_count(4)
    end
    run_irc
  end
  
  def test_a_handler_a_system_message_code
    connection.handle_messages(:command => 1) do |message|
      assert_equal(MESSAGES[:welcome], message.raw)
      read_to_count(1)
    end
    run_irc
  end
  
  def test_a_handler_for_a_named_command_type
    connection.handle_messages(:command => "PING") do |message|
      assert_equal(MESSAGES[:ping], message.raw)
      read_to_count(2)
    end
    run_irc
  end
  
  def test_a_handler_for_a_regexp_matching_command_types
    connection.handle_messages(:command => /\AJOIN|\d{3}\z/) do |message|
      assert_equal(@expected.shift, message.raw)
      @expected.shift
      read_to_count(2)
    end
    run_irc
  end
  
  def test_a_handler_for_a_specific_nick
    connection.handle_messages(:nick => "JEG2") do |message|
      assert_equal(MESSAGES[:ctcp_ping], message.raw)
      read_to_count(1)
    end
    socket.deliver_from_server = MESSAGES.values_at( :ctcp_ping,
                                                     :joined_channel )
    run_irc
  end
  
  def test_a_handler_for_a_regexp_matching_nicks
    connection.handle_messages(:nick => /\A(?!JEG2\z)/) do |message|
      assert_equal(MESSAGES[:joined_channel], message.raw)
      read_to_count(1)
    end
    socket.deliver_from_server = MESSAGES.values_at( :ctcp_ping,
                                                     :joined_channel )
    run_irc
  end
  
  def test_a_handler_for_a_specific_channel
    connection.handle_messages(:channel => "#botwar") do |message|
      assert_match(/(?: #botwar |:#botwar\z)/, message.raw)
      read_to_count(2)
    end
    socket.deliver_from_server = MESSAGES.values_at( :joined_channel,
                                                     :channel_topic,
                                                     :bad_channel_key )
    run_irc
  end
  
  def test_expiring_a_handler_after_it_runs
    connection.handle_message( :command => "PING",
                               :expires => :after_run ) do |message|
      assert_equal(MESSAGES[:ping], message.raw)
      read_to_count(1)
    end
    run_irc
  end
  
  def test_expiring_a_handler_by_return_value
    connection.handle_messages(:expires => :by_return) do |message|
      assert_equal(@expected.shift, message.raw)
      read_to_count(2)
      :expire if @read_count == 2
    end
    run_irc
  end
  
  def test_expiring_a_handler_after_a_time
    connection.handle_messages(:expires => Time.now + 0.1) do |message|
      flunk
    end
    sleep 0.2
    run_irc(:skip_read_check)
  end
  
  def test_setting_a_handler_with_a_bad_key_raises_an_error
    assert_raise(Ender::Errors::MessagePatternKeyError) do
      connection.handle_message(:pattern => "Oops")
    end
  end
  
  def test_install_ping_time_and_version_handlers
    connection.install_ping_time_and_version_handlers
    socket.deliver_from_server = MESSAGES.values_at( :ping,
                                                     :ctcp_ping,
                                                     :ctcp_time,
                                                     :ctcp_version )
    run_irc(:skip_read_check)
    assert_equal( [ "PONG :kubrick.freenode.net\r\n",
                    "NOTICE JEG2 :\001PING\001\r\n",
                    "NOTICE JEG2 :\001TIME #{Time.now}\001\r\n",
                    "NOTICE JEG2 :\001VERSION Ender Bot v#{Ender::VERSION}" +
                    " (#{RUBY_PLATFORM})\001\r\n" ],
                  socket.sent_to_server )
  end
  
  private
  
  def connection(*args)
    @expected                  = MESSAGES.values_at( :welcome,
                                                     :ping,
                                                     :joined_channel,
                                                     :ping )
    socket.deliver_from_server = @expected.dup
    @read_count                = 0
    @read_expected             = false

    @connection = Ender::IRCConnection.new( *( args.empty?          ?
                                               %w[irc.freenode.net] :
                                               args ) )
  end
  
  def read_to_count(count)
    case @read_count += 1
    when count
      @read_expected = true
    when count + 1
      flunk
    end
  end
  
  def run_irc(skip_read_check = false)
    @connection.run
    unless skip_read_check
      assert(@read_expected, "The bot didn't read the expected messages")
    end
  end
  
  def assert_last_queued(messages)
    queued = Array.new
    while message = @connection.send_queue.dequeue
      queued << message
    end
    
    if messages.is_a? Array
      assert_equal(messages, queued[-messages.size..-1])
    else
      assert_equal(messages, queued.last)
    end
  end
end
