#!/usr/bin/env ruby -wKU

require "ostruct"

module Config
  module_function
  
  def load_config_file(path)
    eval <<-END_CONFIG
    config = OpenStruct.new
    #{File.read(path)}
    config
    END_CONFIG
  end
end
