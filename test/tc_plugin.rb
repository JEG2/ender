#!/usr/bin/env ruby -wKU

require "test/unit"

require "ender/plugin"

class TestPlugin < Test::Unit::TestCase
  class Tester < Ender::Plugin
    
  end
  
  class EmptyPlugin < Ender::Plugin; end

  class UnloadMe < Ender::Plugin; end
  
  def test_plugin_loads_all_subclasses
    [Tester, EmptyPlugin].each do |subclass|
      assert_send([Ender::Plugin.available, :include?, subclass])
    end
  end
  
  def test_restrict_to
    assert_send([Ender::Plugin.available, :include?, UnloadMe])
    Ender::Plugin.restrict_to(*%w[tester empty_plugin])
    assert( !Ender::Plugin.available.include?(UnloadMe),
            "Plugin still available" )
    assert_send([Ender::Plugin.available.size, :nonzero?])
  end
  
  def test_load_and_dispatch_to_all
    assert_equal(Array.new, Ender::Plugin.loaded)
    Ender::Plugin.load
    types = Ender::Plugin.available.dup
    Ender::Plugin.loaded.each do |plugin|
      assert_instance_of(types.shift, plugin)
    end
    
    Ender::Plugin.loaded.each do |plugin|
      class << plugin
        alias_method  :saved_dispatch, :dispatch
        attr_accessor :dispatch_calls
        def dispatch(message)
          self.dispatch_calls ||= 0
          self.dispatch_calls += 1
        end
      end
    end
    plan = rand(10) + 1
    plan.times { Ender::Plugin.dispatch(command("not_used")) }
    Ender::Plugin.loaded.each do |plugin|
      assert_equal(plan, plugin.dispatch_calls)
      class << plugin
        remove_method :dispatch
        alias_method  :dispatch, :saved_dispatch
        %w[dispatch_calls dispatch_calls= saved_dispatch].each do |method|
          remove_method method
        end
      end
    end
  end
  
  private
  
  def command(user_entry)
    user_entry
  end
end
