#!/usr/bin/env ruby -wKU

module Ender
  class User
    class Modes
      MODES    = { "O" => :owner,
                   "o" => :op,
                   "h" => :halfop,
                   "v" => :voice }
      MODES_RE = /([-+])([#{Modes::MODES.keys.join}]+) (\S+)/

      class ModeStruct
        def initialize(modes)
          Modes::MODES.each_key do |code|
            instance_variable_set("@#{code}", modes[code])
          end
        end
        
        Modes::MODES.each do |code, mode|
          define_method(code) { instance_variable_get("@#{code}") }
          ["#{code}?", mode, "#{mode}?"].each do |new_name|
            alias_method new_name, code
          end
        end
      end
      
      def initialize
        @modes = Hash.new do |channels, channel|
          channels[channel.to_s] = Hash.new
        end
      end
      
      def []=(channel, mode_str)
        case mode_str
        when "@"
          @modes[channel.to_s]["o"] = true
        when "%"
          @modes[channel.to_s]["h"] = true
        when "+"
          @modes[channel.to_s]["v"] = true
        else
          mode_str.scan(MODES_RE) do |action, codes, _|
            case action
            when "+"
              codes.each_byte { |byte| @modes[channel.to_s][byte.chr] = true }
            when "-"
              codes.each_byte { |byte| @modes[channel.to_s].delete(byte.chr) }
            end
          end
        end
      end
      
      def [](channel)
        ModeStruct.new(@modes[channel.to_s])
      end
      
      def delete(channel)
        @modes.delete(channel.to_s)
      end
    end
    
    def initialize(nick)
      @nick      = nick
      @host_mask = nil
      @away      = nil
      @real_name = nil
      @channels  = Hash.new
      @modes     = Modes.new
    end
    
    attr_accessor :nick, :host_mask, :away, :real_name
    alias_method  :to_s, :nick
    alias_method  :away?, :away
    
    attr_reader :channels, :modes
    
    def join_channel(channel, with_mode = nil)
      channels[channel.to_s] = channel
      modes[channel.to_s]    = with_mode unless with_mode.nil?
    end
    
    def part_channel(channel)
      channels.delete(channel.to_s)
      modes.delete(channel)
      
      channels.empty?
    end
  end
end
