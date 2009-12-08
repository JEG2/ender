#!/usr/bin/env ruby -wKU

require "ender/channel"
require "ender/user"
require "ender/plugin"

module Ender
  class Bot < User
    def initialize(irc_connection, nick, nickserv_password, channels)
      super(nick)
      
      @irc_connection    = irc_connection
      @nickserv_password = nickserv_password
      @users             = Hash.new
      
      Plugin.load(self)
      
      login_and_join(channels)
    end
    
    attr_reader :users
    
    def run
      install_callbacks
      @irc_connection.run
    end
    
    private
    
    def login_and_join(channels)
      @irc_connection.login( @nick     )
      @irc_connection.join(  *channels )
    end
    
    def install_callbacks
      install_debugging_and_protocol_callbacks
      install_channel_managment_callbacks
      install_user_managment_callbacks
      install_plugin_callbacks
    end
    
    def install_debugging_and_protocol_callbacks
      if $DEBUG
        @irc_connection.handle_messages do |m|
          $stderr.puts m.raw.inspect
        end
      end
      @irc_connection.install_ping_time_and_version_handlers
    end
    
    def install_channel_managment_callbacks
      @irc_connection.handle_messages( :nick    => @nick,
                                       :command => "JOIN" ) do |m|
        join_channel(Channel.new(m.params.first))
        @users[@nick] = self
        @irc_connection.send_raw "MODE #{m.params.first}"
        @irc_connection.send_raw "WHO #{m.params.first}"
      end
      @irc_connection.handle_messages(:command => /\A(?:332|TOPIC)\z/) do |m|
        if channel = m.command == "TOPIC"   ?
                     @channels[m.params[0]] :
                     @channels[m.params[1]]
          channel.topic = m.params.last
        end
      end
      @irc_connection.handle_messages(:command => /\A(?:324|MODE)\z/) do |m|
        if channel = m.command == "MODE"    ?
                     @channels[m.params[0]] :
                     @channels[m.params[1]]
          channel.modes = m.raw[/#{Regexp.escape(channel.name)} (.+)/, 1]
        end
      end
      @irc_connection.handle_messages( :nick    => @nick,
                                       :command => "PART" ) do |m|
        if channel = @channels[m.params.first]
          drop_channel(channel)
        end
      end
      @irc_connection.handle_messages(:command => "KICK") do |m|
        if m.params[1] == @nick and (channel = @channels[m.params[0]])
          drop_channel(channel)
        end
      end
      @irc_connection.handle_messages( :nick    => @nick,
                                       :command => "QUIT" ) do |m|
        quit
      end
      @irc_connection.handle_messages(:command => "ERROR") do |m|
        quit
      end
    end
    
    def install_user_managment_callbacks
      @irc_connection.handle_messages(:command => 353) do |m|
        if channel = @channels[m.params[2]]
          m.params.last.split.each do |nick|
            add_user_to_channel(nick.sub(/\A[@%+]/, ""), channel, $&)
          end
        end
      end
      @irc_connection.handle_messages(
        :nick    => /\A(?!#{Regexp.escape(@nick)}\z)/,
        :command => "JOIN"
      ) do |m|
        if channel = @channels[m.params.first]
          add_user_to_channel(m.nick, channel)
          @irc_connection.send_raw "WHOIS :#{m.nick}"
        end
      end
      @irc_connection.handle_messages(:command => 352) do |m|
        if channel = @channels[m.params[1]]
          add_user_to_channel(m.params[5], channel, m.params[6][/[@%+]\z/])
          @users[m.params[5]].host_mask = m.params[2..3].join("@")
          @users[m.params[5]].away      = case m.params[6][1, 1]
                                          when "H" then false
                                          when "G" then true
                                          else          nil
                                          end
          @users[m.params[5]].real_name = m.params[-1].sub(/\A\d+\s+/, "")
        end
      end
      
      @irc_connection.handle_messages(:command => "MODE") do |m|
        if channel = @channels[m.params.first]
          m.params.join(" ").scan(User::Modes::MODES_RE) do |_, _, nick|
            if user = @users[nick]
              user.modes[channel] = $&
            end
          end
        end
      end
      @irc_connection.handle_messages(
        :nick    => /\A(?!#{Regexp.escape(@nick)}\z)/,
        :command => "PART"
      ) do |m|
        if (channel = @channels[m.params.first]) and (user = @users[m.nick])
          drop_user_from_channel(user, channel)
        end
      end
      @irc_connection.handle_messages(:command => "KICK") do |m|
        if m.params[1] != @nick and (channel = @channels[m.params.first]) and
                                    (user    = @users[m.params[1]])
          drop_user_from_channel(user, channel)
        end
      end
      @irc_connection.handle_messages(
        :nick    => /\A(?!#{Regexp.escape(@nick)}\z)/,
        :command => "QUIT"
      ) do |m|
        if user = @users[m.nick]
          user.channels.each_value do |channel|
            drop_user_from_channel(user, channel)
          end
        end
      end
    end
    
    def install_plugin_callbacks
      @irc_connection.handle_messages { |message| Plugin.dispatch(message) }
    end
    
    def drop_channel(channel)
      part_channel(channel)
      @users.delete_if { |_, user| user.part_channel(channel) }
    end
    
    def add_user_to_channel(nick, channel, mode = nil)
      @users[nick] ||= User.new(nick)
      @users[nick].join_channel(channel, mode)
    end
    
    def drop_user_from_channel(user, channel)
      @users.delete(user.nick) if user.part_channel(channel)
    end
    
    def quit
      @channels.each_value { |channel| drop_channel(channel) }
    end
  end
end
