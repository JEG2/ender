#!/usr/bin/env ruby -wKU

require "stringio"

require "test_helper"

require "ender"

require "mocks/socket"

class TestBot < Test::Unit::TestCase
  def test_logs_in_and_joins_channels_on_creation
    bot.run
    assert_equal( [ "NICK ender_bot\r\n",
                    "USER ender_bot 0 * :'ender_bot' IRC Bot\r\n",
                    "JOIN #botwar\r\n" ],
                  socket.sent_to_server )
  end
  
  def test_installs_a_debugging_handler_when_debug_is_set
    old_debug  = $DEBUG
    $DEBUG     = true
    old_stderr = $stderr
    $stderr    = StringIO.new
    
    messages = MESSAGES.values_at(:welcome, :joined_channel)
    bot(*messages).run
    $stderr.rewind
    assert_equal(messages.map { |m| "#{m.inspect}\n" }, $stderr.readlines)
    
    $DEBUG  = old_debug
    $stderr = old_stderr
  end
  
  def test_installs_ping_time_and_version_handlers_before_run
    bot(:ping, :ctcp_ping, :ctcp_time, :ctcp_version).run
    assert_equal( %w[PONG] + %w[NOTICE] * 3,
                  socket.sent_to_server[-4..-1].map { |m| m[/\S+/] } )
  end
  
  def test_records_channels_joined
    assert_nil(bot(:joined_channel).channels["#botwar"])
    assert(@bot.users.empty?, "User list was not empty")
    @bot.run
    assert_instance_of(Ender::Channel, @bot.channels["#botwar"])
    assert_equal({@bot.nick => @bot}, @bot.users)
  end
  
  def test_requests_channel_and_user_details_on_join
    bot(:joined_channel).run
    assert_equal( [ "MODE #botwar\r\n",
                    "WHO #botwar\r\n" ],
                  socket.sent_to_server.last(2) )
  end
  
  def test_records_channels_topic
    assert_nil(bot(:joined_channel, :channel_topic).channels["#botwar"])
    @bot.run
    assert_equal( MESSAGES[:channel_topic][/[^:]+\z/],
                  @bot.channels["#botwar"].topic )

    socket.deliver_from_server = MESSAGES.values_at(:topic_change)
    @irc.run
    assert_equal( MESSAGES[:topic_change][/[^:]+\z/],
                  @bot.channels["#botwar"].topic )
  end
  
  def test_tracks_channel_mode_changes
    bot(:joined_channel, :channel_mode).run
    channel = @bot.channels["#botwar"]
    assert_equal(true,     channel.secret)
    assert_equal(true,     channel.no_outside_messages)
    assert_equal("secret", channel.key)

    socket.deliver_from_server = MESSAGES.values_at(:channel_mode_change)
    @irc.run
    assert_equal(true, channel.topic_protected)
  end
  
  def test_records_channel_parted
    assert_bot_parts_channel_on(:parted_channel)
  end
  
  def test_treats_kick_as_channel_parted
    assert_bot_parts_channel_on(:kicked_from_channel)
  end
  
  def test_parts_all_channels_on_quit
    assert_bot_parts_all_channels_on(:quit)
  end
  
  def test_treats_error_as_client_quit
    assert_bot_parts_all_channels_on(:connection_error)
  end
  
  def test_adds_users_to_channel_from_name_list
    bot(:joined_channel, :name_list).run
    m = message(:name_list)
    m.params.last.scan(/[^@%+\s]+/).each do |nick|
      if nick == @bot.nick
        assert_instance_of(Ender::Bot, @bot.users[nick])
      else
        assert_instance_of(Ender::User, @bot.users[nick])
      end
    end
    
    assert( @bot.users[m.params.last[/@(\S+)/, 1]].modes[m.params[2]].op,
            "Operator status not detected" )
  end
  
  def test_records_users_joining_channels
    bot(:joined_channel, :name_list).run
    assert_nil(@bot.users["JEG2"])

    socket.deliver_from_server = MESSAGES.values_at(:user_joined)
    @irc.run
    assert_instance_of(Ender::User, @bot.users["JEG2"])
  end
  
  def test_sends_whois_command_when_user_joins_a_channel
    bot(:joined_channel, :user_joined).run
    assert_equal("WHOIS :JEG2\r\n", socket.sent_to_server.last)
  end
  
  def test_records_hostmask_from_who_response
    bot(:joined_channel, :name_list).run
    assert_nil(@bot.users["itsderek23"].host_mask)
    
    socket.deliver_from_server = MESSAGES.values_at(:who_response)
    @irc.run
    assert_equal( message(:who_response).params[2..3].join("@"),
                  @bot.users["itsderek23"].host_mask )
  end
  
  def test_records_user_mode_changes
    bot(:joined_channel, :user_joined).run
    assert_nil(@bot.users["JEG2"].modes["#botwar"].op)

    socket.deliver_from_server = MESSAGES.values_at(:user_mode_change)
    @irc.run
    assert_equal(true, @bot.users["JEG2"].modes["#botwar"].op)
  end
  
  def test_records_users_parting_channels
    bot(:joined_channel, :user_joined, :user_parted).run
    assert_nil(@bot.users["JEG2"])
  end
  
  def test_treats_user_kicked_as_parting_a_channel
    bot(:joined_channel, :user_joined, :user_kicked).run
    assert_nil(@bot.users["JEG2"])
  end
  
  def test_treats_user_quit_as_a_part_from_all_channels
    bot( :joined_channel,
         MESSAGES[:joined_channel].sub("#botwar", "#other"),
         :user_joined,
         MESSAGES[:user_joined].sub("#botwar", "#other") ).run
    assert_instance_of(Ender::User,    @bot.users["JEG2"])
    assert_instance_of(Ender::Channel, @bot.users["JEG2"].channels["#botwar"])
    assert_instance_of(Ender::Channel, @bot.users["JEG2"].channels["#other"])

    socket.deliver_from_server = MESSAGES.values_at(:user_quit)
    @irc.run
    assert_nil(@bot.users["JEG2"])
  end
  
  private
  
  def bot(*messages)
    socket.deliver_from_server = messages.map do |m|
      m.is_a?(Symbol) ? MESSAGES[m] : m
    end
    @irc = Ender::IRCConnection.new("irc.freenode.net")
    @bot = Ender::Bot.new(@irc, "ender_bot", nil, %w[#botwar])
  end
  
  def assert_bot_parts_channel_on(message)
    bot(:joined_channel).run
    assert_instance_of(Ender::Channel, @bot.channels["#botwar"])

    socket.deliver_from_server = MESSAGES.values_at(message)
    @irc.run
    assert_nil(@bot.channels["#botwar"])
  end
  
  def assert_bot_parts_all_channels_on(message)
    bot( :joined_channel,
         MESSAGES[:joined_channel].sub("#botwar", "#other") ).run
    assert_instance_of(Ender::Channel, @bot.channels["#botwar"])
    assert_instance_of(Ender::Channel, @bot.channels["#other"])

    socket.deliver_from_server = MESSAGES.values_at(message)
    @irc.run
    assert_nil(@bot.channels["#botwar"])
    assert_nil(@bot.channels["#other"])
  end
end
