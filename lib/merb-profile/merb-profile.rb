class Merb::Profile
  attr_reader :results
  cattr_accessor :profiled_actions
  self.profiled_actions = {}

  def push(name, result)
    @results.push([name, result]) rescue @results = [[name, result]]
  end

  def render_profiling(name = nil)
    return "<h1>No profiling data</h1>" if @results.nil?
    output = @@tpl_styles
    @results.each do |name, result|
      output << "<h1>Profiling report for #{name}</h1>\n"
      printer = RubyProf::GraphHtmlPrinter.new(result)
      printer.print(output, :min_percent => 0)
      output << "<br /><br />\n"
    end
    output
  end

  cattr_reader :tpl_styles, :tpl_content
  @@tpl_styles = IO.read(File.dirname(__FILE__)/"styles.txt") rescue ""
  @@tpl_content = IO.read(File.dirname(__FILE__)/"content.txt") rescue ""

  module ControllerInstanceMethods
    def profile(name)
      output = nil
      result = RubyProf.profile do
        output = yield
      end
      Merb::Controller._profile.push(name, result)
      output
    end

    def clear_profiling
      @results.clear
    end

    def render_profiling(name = nil)
      Merb::Controller._profile.render_profiling(name)
    end

    private

    def profile_action_before
      actions = Merb::Controller._profile.profiled_actions[controller_name]
      return unless actions && actions.include?(action_name.to_sym)
      RubyProf.start
    end

    def profile_action_after
      actions = Merb::Controller._profile.profiled_actions[controller_name]
      return unless actions && actions.include?(action_name.to_sym)
      Merb::Controller._profile.push(controller_name / action_name, RubyProf.stop)
    end
  end

  module ControllerClassMethods
    def profile_action(*actions)
      if actions.any? && Merb::Profile.profiled_actions.empty?
        before(:profile_action_before)
        after(:profile_action_after)
      end
      actions.each do |action| 
        _actions = Merb::Profile.profiled_actions[controller_name] ||= []
        _actions << action
      end
    end
  end
end

class RubyProf::GraphHtmlPrinter
  def template
    Merb::Profile.tpl_content
  end
end

module Merb #:nodoc:
  class Controller #:nodoc:
    cattr_reader :_profile
    @@_profile = Merb::Profile.new
    # extends Merb::Controller with new instance methods
    include Merb::Profile::ControllerInstanceMethods
    class << self #:nodoc:
      # extends Merb::Controller with new class methods
      include Merb::Profile::ControllerClassMethods
    end
  end
end

