#!/usr/bin/env ruby -wKU

require "socket"
require "timeout"

require "ender/errors"
require "ender/irc_connection/message"
require "ender/irc_connection/send_queue"

module Ender
  class IRCConnection
    def initialize(host, port = 6667)
      @server           = TCPSocket.new(host, port)
      @nick             = nil
      @message_handlers = Array.new
      @login_tasks      = Array.new
      @send_queue       = SendQueue.new
    end
    
    attr_reader :nick, :send_queue
    
    def logged_in?
      @login_tasks.empty?
    end
    
    def login(nick, password = nil)
      @login_tasks << :login
      
      send_raw "NICK #{nick}"
      send_raw "USER #{nick} 0 * :'#{nick}' IRC Bot"
      handle_message( :command => /\A(?:43[1236]|46[12]|001)\z/,
                      :expires => :after_run ) do |message|
        if message.to_i == 1
          @nick = nick
        else
          raise Errors::LoginError, "Could not login:  #{message.params.last}"
        end
        @login_tasks.delete(:login)
      end
      
      send_message "NickServ", "IDENTIFY #{password}" if password
    end
    
    def join(*channels)
      channels.each do |channel|
        @login_tasks << channel unless logged_in?
        
        send_raw "JOIN #{channel}"
        handle_message( :command => /\A(?:40[135]|437|47[01345]|JOIN)\z/,
                        :channel => channel,
                        :expires => :after_run ) do |message|
          if message.command == "JOIN"
            @login_tasks.delete(message.params.first)
          elsif not logged_in?
            raise Errors::JoinError,
                  "Could not join channel:  #{message.params.last}"
          end
        end
      end
    end
    
    def send_raw(raw_message)
      @send_queue.enqueue("#{raw_message.strip}\r\n")
    end
    
    def send_message(to, message)
      send_raw "PRIVMSG #{to} :#{message}"
    end
    
    def send_notice(to, message)
      send_raw "NOTICE #{to} :#{message}"
    end
    
    def quit(message = nil)
      send_raw "QUIT#{" :#{message}" if message}"
      @quitting = true
    end
    
    def handle_messages(options = Hash.new, &handler)
      options.each_key do |key|
        unless [:expires, :nick, :command, :channel].include? key
          raise Errors::MessagePatternKeyError, "Bad key: #{key}"
        end
      end
      @message_handlers << [options, handler]
    end
    alias_method :handle_message, :handle_messages
    
    def install_ping_time_and_version_handlers
      handle_message(:command => "PING") do |message|
        send_raw "PONG :#{message.params.last}"
      end
      handle_messages(:command => "PRIVMSG") do |message|
        if message.ctcp_command? "PING"
          send_notice message.nick, message.params.last
        elsif message.ctcp_command? "TIME"
          send_notice message.nick, "\001TIME #{Time.now}\001"
        elsif message.ctcp_command? "VERSION"
          send_notice message.nick, "\001VERSION Ender Bot v#{Ender::VERSION}" +
                                    " (#{RUBY_PLATFORM})\001"
        end
      end
    end
    
    def run
      catch(:quit) do
        loop do
          while (mes_or_wait = @send_queue.dequeue) and mes_or_wait.is_a? String
            begin
              @server.print mes_or_wait
            rescue Exception
              throw :quit
            end
          end
        
          begin
            raw_message = nil
            Timeout.timeout([mes_or_wait || 1, 1].min) do
              raw_message = @server.gets
            end
            throw :quit if raw_message.nil?
          rescue Timeout::Error
            # do nothing, just return to the event loop
          rescue Exception
            throw :quit
          end
        
          unless raw_message.nil?
            message = Message.new(raw_message, self)
            @message_handlers.delete_if do |options, handler|
              exp = options[:expires]
              if exp.is_a?(Time) and exp < Time.now
                true
              elsif message.match?(options)
                result = handler[message]
                (exp == :by_return and result == :expire) or exp == :after_run
              else
                false
              end
            end
          end
        end
      end
    end
  end
end
