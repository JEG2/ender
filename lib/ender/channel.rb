#!/usr/bin/env ruby -wKU

module Ender
  class Channel
    MODES      = { "a" => :anonymous,
                   "i" => :invite_only,
                   "m" => :moderated,
                   "n" => :no_outside_messages,
                   "q" => :quiet,
                   "p" => :private,
                   "s" => :secret,
                   "r" => :reop,
                   "t" => :topic_protected,
                   "k" => :key,
                   "l" => :limit,
                   "b" => :ban_mask,
                   "e" => :exception_mask,
                   "I" => :invitation_mask }
    MODE_CODES = "[#{MODES.keys.join}]+"
    
    def initialize(name)
      @name  = name
      @topic = nil
      @modes = Hash.new
    end
    
    attr_reader  :name
    alias_method :to_s, :name
    
    attr_accessor :topic
    
    def modes=(mode_str)
      mode_str.scan(/\+#{MODE_CODES}(?: [^+-]\S*)?|-#{MODE_CODES}/) do |codes|
        case codes[0, 1]
        when "+"
          codes, last_value = codes[1..-1].split
          codes[0..-2].each_byte { |byte| @modes[byte.chr] = true }
          @modes[codes[-1].chr] = last_value || true
        when "-"
          codes[1..-1].each_byte { |byte| @modes.delete(byte.chr) }
        end
      end
    end
    
    MODES.each do |code, name|
      define_method(code) { @modes[code] }
      ["#{code}?", name, "#{name}?"].each do |new_name|
        alias_method new_name, code
      end
    end
  end
end
