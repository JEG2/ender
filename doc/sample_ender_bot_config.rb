#!/usr/bin/env ruby -wKU

# 
# This file shows the configuration options for the Ender IRC Bot.  You should
# copy this file to a convenient location and customize it to your needs.  You
# can point the bot at this file when you launch it.
# 
# Any Ruby code you would like run at start-up is a valid addition to this file.
# 

# The code below sets the IRC server you wish the bot to connect to:
config.irc_server = "irc.freenode.net"

# 
# The code below sets the port that the server will be contacted on.  The port
# below is the default IRC port and it's unlikely you will need to change this:
# 
config.irc_port = 6667

# 
# The code below should be set to a unique nickname for your bot on your IRC
# server.  You definitely want to change this default:
# 
config.bot_nick = "ender_bot"  # CHANGE ME!

# 
# The code below creates the list of rooms you want to bot to connect to at
# start-up.  You can also have the bot join other channels once it is running:
# 
config.channels = %w[#botwar #ender_bot]
# 
# If you need to join a private channel uncomment the code below and set the
# channel name and password.  Note that the colon is not part of your password
# and should be left alone:
# 
# (config.channels ||= Array.new) << "#private :password"

# 
# The two settings below control the bot's flooding protection.  These will
# prevent the bot from sending messages too fast and being kicked off of IRC.
# You can adjust the number of messages that can be sent over what number of
# seconds to what works well for your server.  These defaults are the settings I
# found to work well with Freenode.  To disable this protection, set the message
# limit to zero.
# 
config.flooding_time_limit    = 1
config.flooding_message_limit = 10

# Add any addition Ruby code you need to run below this line...
