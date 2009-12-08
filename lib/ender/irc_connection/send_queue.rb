#!/usr/bin/env ruby -wKU

module Ender
  class IRCConnection
    class SendQueue
      def initialize
        @messages               = Array.new
        @send_times             = Array.new
        @flooding_time_limit    = 0
        @flooding_message_limit = 0
      end
      
      attr_accessor :flooding_time_limit, :flooding_message_limit
      
      def enqueue(*messages)
        @messages.unshift(*messages.reverse)
      end
      
      def dequeue
        if @messages.empty?
          nil
        elsif can_send?
          @send_times.unshift(Time.now)
          @messages.pop
        else
          @flooding_time_limit - (Time.now - @send_times.last)
        end
      end
      
      def empty?
        @messages.empty?
      end
      
      private
      
      def can_send?
        until @send_times.empty? or
              @send_times.last + @flooding_time_limit > Time.now
          @send_times.pop
        end
        @send_times.empty? or @send_times.size < @flooding_message_limit
      end
    end
  end
end
