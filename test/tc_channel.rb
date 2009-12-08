#!/usr/bin/env ruby -wKU

require "test/unit"

require "ender/channel"

class TestChannel < Test::Unit::TestCase
  def setup
    @channel = Ender::Channel.new("#botwar")
  end
  
  def test_name_is_string_representation_of_the_channel
    assert_equal("#botwar", @channel.name)
    assert_equal("#botwar", @channel.to_s)
  end
  
  def test_updating_the_channel_topic
    assert_nil(@channel.topic)
    @channel.topic = "Topic changed!"
    assert_equal("Topic changed!", @channel.topic)
  end
  
  def test_mode_readers_and_aliases
    @channel.modes = "+snk secret"
    Ender::Channel::MODES.each do |code, name|
      assert_equal(@channel.send(code), @channel.send(name))
      assert_equal(@channel.send(code), @channel.send("#{name}?"))
      assert_equal(@channel.send(code), @channel.send("#{code}?"))
    end
  end
  
  def test_adjust_mode_settings
    Ender::Channel::MODES.each_key do |code|
      assert_nil(@channel.send(code))
    end
    
    @channel.modes = "+snk secret"
    assert_equal(true,     @channel.secret)
    assert_equal(true,     @channel.no_outside_messages)
    assert_equal("secret", @channel.key)
    
    @channel.modes = "+t"
    assert_equal(true, @channel.topic_protected)
    
    @channel.modes = "-t"
    assert_nil(@channel.topic_protected)

    @channel.modes = "+t -n"
    assert_equal(true, @channel.topic_protected)
    assert_nil(@channel.no_outside_messages)
  end
end
