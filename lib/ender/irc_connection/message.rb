#!/usr/bin/env ruby -wKU

require "ender/errors"

module Ender
  class IRCConnection
    class Message
      PREFIX_RE = / :(                   # colon
                      ([^!@\040]+)       # nick or server
                      (?:!([^@\040]+))?  # user
                      (?:@([^\040]+))?   # host
                    )
                    \040                 # space
                  /x
      RE        = / \A (?:#{PREFIX_RE})?        # prefix
                       ([A-Za-z]+|\d{3})        # command
                       ((?:\040[^:][^\040]*)*)  # params, minus last
                       (?:\040:?(.*))?          # last param
                       \z /x
      
      def initialize(raw_message, irc_connection)
        @raw = raw_message
        
        @raw.strip =~ RE or raise "Malformed IRC command."
        @prefix    =  $1
        @nick      =  $2
        @user      =  $3
        @host      =  $4
        @command   =  $5
        @params    =  $6.split + Array($7)
        
        @irc_connection = irc_connection
      end
      
      attr_reader :raw, :prefix, :command, :params, :nick, :user, :host

      alias_method :to_s,   :raw
      alias_method :server, :nick
      
      def content
        @params.last.gsub( / (?: \A\001             |            # CTCP start
                                 \001\z             |            # CTCP end
                                 [\002\026\037\017] |            # b, i, u
                                 \003[0-9]{1,2}(?:,[0-9]{1,2})?  # colors
                             ) /x, "" )
      end
      
      def ctcp_command?(command = nil)
        @command == "PRIVMSG"                                 and
        ( (command.nil? and @params.last =~ /\A\001.*\001\z/) or
          @params.last =~ /\A\001#{Regexp.escape(command)}\b.*\001\z/ )
      end
      
      def match?(pattern)
        nic, cmd, cha = pattern.values_at(:nick, :command, :channel)
        ( cmd.nil?                                       or
          (cmd.is_a?(Integer) and cmd      == to_i)      or
          (cmd.is_a?(String)  and cmd      == @command)  or
          (cmd.is_a?(Regexp)  and @command =~ cmd) )     and
        ( nic.nil?                                       or
          (nic.is_a?(String)  and nic      == @nick )    or
          (nic.is_a?(Regexp)  and @nick    =~ nic) )     and
        ( cha.nil?                                       or
          params[0..-2].include?(cha)                    or
          (@command == "JOIN" and params.first == cha) )
      end
      
      def to_i
        command.to_i
      end
      
      def reply(new_message)
        if command == "PRIVMSG"
          if params.first == @irc_connection.nick
            @irc_connection.send_message(nick, new_message)
          else
            @irc_connection.send_message( params.first,
                                          "#{nick}: #{new_message}" )
          end
        else
          raise Errors::ReplyToNonPrivmsgError,
                "The message is a #{command}, not a PRIVMSG"
        end
      end
    end
  end
end
