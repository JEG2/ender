#!/usr/bin/env ruby -wKU

require "open-uri"

module Ender
  class Plugin
    class Google < Plugin
      def google_command(message, user, channel)
        if message.content.strip =~ /google\s+(\S.*)\z/m
          search = $1.gsub(/[^a-zA-Z0-9_.\-]/) { |s| sprintf('%%%02x', s[0]) }
          open( "http://www.google.com/search?ie=utf8&oe=utf8&q=#{search}",
                "User-Agent" => "Ender Bot" ) do |results|
            if results.status.first == "200"
              links = results.read
              if links =~ /<a href="([^"]+)" class=l>(.+?)<\/a>/
                link = $1#.decode_entities
                desc = $2.gsub('<b>', "\x02").gsub('</b>', "\x0f")#.decode_entities
                message.reply "#{link} (#{desc})"
              elsif links.include? "did not match any documents"
                message.reply "Nothing found."
              else
                message.reply "Error parsing Google output."
              end
            else
              message.reply "Google returned an error:  #{results.status.join(' ')}"
            end
          end
        else
          message.reply "USAGE:  google SEARCH_STRING"
        end
      end
    end
  end
end
