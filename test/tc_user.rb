#!/usr/bin/env ruby -wKU

require "test/unit"

require "ender/channel"
require "ender/user"

class TestUser < Test::Unit::TestCase
  def setup
    @user = Ender::User.new("JEG2")
  end
  
  def test_nick_is_string_representation_of_the_user
    assert_equal("JEG2", @user.nick)
    assert_equal("JEG2", @user.to_s)
  end
  
  def test_updating_the_host_mask
    assert_nil(@user.host_mask)
    @user.host_mask = "n=JEG2@ip68-97-89-187.ok.ok.cox.net"
    assert_equal("n=JEG2@ip68-97-89-187.ok.ok.cox.net", @user.host_mask)
  end
  
  def test_mode_readers_and_aliases
    @user.modes["#botwar"] = "+ov #{@user.nick}"
    modes                  = @user.modes["#botwar"]
    Ender::User::Modes::MODES.each do |code, mode|
      assert_equal(modes.send(mode), modes.send(code))
      assert_equal(modes.send(mode), modes.send("#{mode}?"))
      assert_equal(modes.send(mode), modes.send("#{code}?"))
    end
  end
  
  def test_adjust_mode_settings
    assert_all_modes_nil("#botwar")
    
    @user.modes["#botwar"] = "+v #{@user.nick}"
    assert_equal(true, @user.modes["#botwar"].voice)

    assert_all_modes_nil("#other")
    
    @user.modes["#botwar"] = "-v #{@user.nick}"
    assert_nil(@user.modes["#botwar"].voice)
  end
  
  def test_user_joins_a_room
    assert_nil(@user.channels["#botwar"])
    @user.join_channel(Ender::Channel.new("#botwar"))
    assert_instance_of(Ender::Channel, @user.channels["#botwar"])
    assert_all_modes_nil("#botwar")
  end
  
  def test_user_joins_a_room_with_modes
    assert_nil(@user.channels["#botwar"])
    @user.join_channel(Ender::Channel.new("#botwar"), "+")
    assert_instance_of(Ender::Channel, @user.channels["#botwar"])
    modes = @user.modes["#botwar"]
    Ender::User::Modes::MODES.each_value do |mode|
      if mode == :voice
        assert_equal(true, modes.send(mode))
      else
        assert_nil(modes.send(mode))
      end
    end
  end
  
  def test_user_parts_a_channel
    @user.join_channel(Ender::Channel.new("#first"))
    @user.join_channel(Ender::Channel.new("#botwar"), "@")
    assert_equal(true, @user.modes["#botwar"].op)
    
    assert_equal(false, @user.part_channel("#first"))
    assert_equal(true,  @user.part_channel("#botwar"))
    assert_all_modes_nil("#botwar")
  end
  
  private
  
  def assert_all_modes_nil(channel)
    modes = @user.modes[channel]
    Ender::User::Modes::MODES.each_value do |mode|
      assert_nil(modes.send(mode))
    end
  end
end
