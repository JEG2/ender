#!/usr/bin/env ruby -wKU

module Ender
  class Plugin
    class << self
      attr_accessor :command_prefix
      
      def available
        @available ||= Array.new
      end

      def inherited(loaded_plugin)
        available << loaded_plugin
      end

      def restrict_to(*plugins)
        names = plugins.map { |name| name.downcase.delete("^a-z") }
        available.delete_if do |plugin|
          not names.include? plugin.to_s.downcase[/[^:]+\z/]
        end
      end

      def loaded
        @loaded ||= Array.new
      end

      def load(bot)
        available.each do |plugin|
          loaded     << plugin.new
          loaded.last.bot =  bot
        end
      end

      def dispatch(*args)
        loaded.each { |plugin| plugin.dispatch(*args) }
      end
    end

    self.command_prefix = "!"
    COMMAND_RE          = / \A\s*
                            (#{Regexp.escape(Plugin.command_prefix)})?
                            \s*([A-Za-z_]\w*) /x
    
    attr_accessor :bot
    
    def dispatch(message)
      if message.command == "PRIVMSG" and message.content =~ COMMAND_RE
        is_command = $1
        command    = $2
        from       = bot.channels[message.params.first] ||
                     bot.users[message.params.first]
        @handlers  = Array.new
        if is_command and from.is_a? Channel
          @handlers.concat(%W[#{command}_public_command #{command}_command])
        elsif from.is_a? User
          @handlers.concat(%W[#{command}_private_command #{command}_command])
        end
        @handlers.each do |handler|
          send(handler, message, bot.users[message.nick], from) if respond_to? handler
        end
      end
    end
  end
end

require "ender/plugin/google"
