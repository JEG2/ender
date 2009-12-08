#!/usr/bin/env ruby -wKU

require "test/unit"
require "tempfile"

require "config"

class TestConfig < Test::Unit::TestCase
  def test_config_returns_a_customized_ostruct
    assert_instance_of(OpenStruct, config)
  end
  
  def test_config_object_is_passed_into_the_file_and_used_to_set_options
    c = config(<<-END_SETTINGS)
    config.string_setting  = "just a String"
    config.integer_setting = 41
    END_SETTINGS
    assert_equal("just a String", c.string_setting)
    assert_equal(41,              c.integer_setting)
  end
  
  def test_exceptions_bubble_up_to_the_caller
    assert_raise(RuntimeError) do
      config(<<-END_ERROR)
      raise "Oops!"
      END_ERROR
    end
  end
  
  private
  
  def config(content = String.new)
    cf = Tempfile.new("ender_config_test")
    cf << content
    cf.flush
    Config.load_config_file(cf.path)
  end
end