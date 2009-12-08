#!/usr/bin/env ruby -wKU

module Ender
  module Errors
    class LoginError             < RuntimeError; end
    class JoinError              < RuntimeError; end
    class MessagePatternKeyError < RuntimeError; end
    class ReplyToNonPrivmsgError < RuntimeError; end
  end
end
