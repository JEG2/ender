#!/usr/bin/env ruby -wKU

require File.join(File.dirname(__FILE__), "test_helper")

class TestMessage < Test::Unit::TestCase
  def test_message_stores_the_raw_message
    MESSAGES.each_value do |raw_message|
      assert_equal(raw_message, message(raw_message).raw)
    end
  end
  
  def test_to_s_is_an_alias_for_raw
    MESSAGES.each_value do |raw_message|
      m = message(raw_message)
      assert_equal(m.raw, m.to_s)
    end
  end
  
  def test_message_extracts_command
    m = message(:welcome)
    assert_equal("001", m.command)
    assert_equal(1,     m.to_i)
    
    m = message(:ping)
    assert_equal(MESSAGES[:ping][/\S+/], m.command)
    assert_equal(0,                      m.to_i)
  end
  
  def test_params_are_collected
    assert_equal(%w[kubrick.freenode.net], message(:ping).params)
    assert_equal( %w[ender_bot A\ private\ message],
                  message(:private_message).params )
  end
  
  def test_final_param_is_unescaped_from_irc_protocol
    MESSAGES.each_value do |raw_message|
      m = message(raw_message)
      next if m.params.empty?
      assert_match(/\A[^:]/, m.params.last)
    end
  end
  
  def test_content_is_final_param_without_formatting
    m = message(:private_message)
    assert_equal(m.params.last, m.content)
    
    m = message(:formatted_message)
    assert_not_equal(m.params.last,            m.content)
    assert_equal("bold italic underline blue", m.content)
  end
  
  def test_symbol_params_are_parsed_correctly
    m = message(:nick_in_use)
    assert_equal(%w[* JEG2 Nickname\ is\ already\ in\ use.], m.params)
  end
  
  def test_prefix_is_parsed
    m = message(:ping)
    assert_nil(m.prefix)
    %w[nick user host].each do |attribute|
      assert_nil(m.send(attribute))
    end
    
    m = message(:welcome)
    assert_equal(MESSAGES[:welcome][/[^:\s]+/], m.prefix)
    assert_equal(MESSAGES[:welcome][/[^:\s]+/], m.server)
    
    m = message(:private_message)
    assert_equal(MESSAGES[:private_message][/[^:\s]+/],     m.prefix)
    assert_equal(MESSAGES[:private_message][/[^:!]+/],      m.nick)
    assert_equal(MESSAGES[:private_message][/!([^@]+)/, 1], m.user)
    assert_equal(MESSAGES[:private_message][/@(\S+)/, 1],   m.host)
  end
  
  def test_ctcp_commands_are_recognized
    %w[ping time version].each do |command|
      assert( message(:"ctcp_#{command}").ctcp_command?,
              "Failed to detect a CTCP command" )
    end
  end
  
  def test_specific_ctcp_command_recognition
    m = message(:ctcp_ping)
    assert(!m.ctcp_command?("TIME"), "CTCP PING recognized as CTCP TIME")
    assert(m.ctcp_command?("PING"), "CTCP PING not recognized")
  end
  
  def test_ctcp_command_param_is_unescaped
    assert_equal("PING", message(:ctcp_ping).content)
  end
  
  def test_reply_to_channel_message
    m = message(:channel_message)
    m.reply("Test reply.")
    assert_equal( "PRIVMSG #{m.params.first} :#{m.nick}: Test reply.\r\n", 
                  connection.sent_messages.last )
  end
  
  def test_reply_to_private_message
    m = message(:private_message)
    m.reply("Private reply.")
    assert_equal( "PRIVMSG #{m.nick} :Private reply.\r\n",
                  connection.sent_messages.last )
  end
  
  def test_reply_to_a_non_privmsg_fails
    assert_raise(Ender::Errors::ReplyToNonPrivmsgError) do
      message(:welcome).reply("Boom!")
    end
  end
end
