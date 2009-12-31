module Boson::Commands::Core #:nodoc:
  extend self

  def config
    command_attributes = Boson::Command::ATTRIBUTES + [:usage, :full_name, :render_options]
    library_attributes = Boson::Library::ATTRIBUTES + [:library_type]

    commands = {
      'render'=>{:description=>"Render any object using Hirb"},
      'menu'=>{:description=>"Provide a menu to multi-select elements from a given array"},
      'usage'=>{:description=>"Print a command's usage", :options=>{[:verbose, :V]=>:boolean}},
      'commands'=>{
        :description=>"List or search commands", :default_option=>'query',
        :options=>{ :index=>{:type=>:boolean, :desc=>"Searches index"}},
        :render_options=>{
          :query=>{:keys=>command_attributes, :default_keys=>'full_name'},
          :fields=>{:default=>[:full_name, :lib, :alias, :usage, :description], :values=>command_attributes},
          :filters=>{:default=>{:render_options=>:inspect, :options=>:inspect, :args=>:inspect}}
        }
      },
      'libraries'=>{
        :description=>"List or search libraries", :default_option=>'query',
        :options=>{ :index=>{:type=>:boolean, :desc=>"Searches index"} },
        :render_options=>{
          :query=>{:keys=>library_attributes, :default_keys=>'name'},
          :fields=>{:default=>[:name, :commands, :gems, :library_type], :values=>library_attributes},
          :filters=>{:default=>{:gems=>[:join, ','],:commands=>:size}, :desc=>"Filters to apply to library fields" }}
      },
      'load_library'=>{:description=>"Load a library", :options=>{[:verbose,:V]=>true}}
    }

    {:namespace=>false, :library_file=>File.expand_path(__FILE__), :commands=>commands}
  end

  def commands(options={})
    options[:index] ? (Boson::Index.read || true) && Boson::Index.commands : Boson.commands
  end

  def libraries(options={})
    options[:index] ? (Boson::Index.read || true) && Boson::Index.libraries : Boson.libraries
  end

  def load_library(library, options={})
    Boson::Manager.load(library, options)
  end

  def render(object, options={})
    Boson::View.render(object, options)
  end

  def menu(output, options={}, &block)
    Hirb::Console.format_output(output, options.merge(:class=>"Hirb::Menu"), &block)
  end

  def usage(command, options={})
    msg = (cmd = Boson::Command.find(command)) ? "#{command} #{cmd.usage}" : "Command '#{cmd}' not found"
    puts msg
    if cmd && options[:verbose]
      if cmd.options && !cmd.options.empty?
        puts "\nLOCAL OPTIONS"
        cmd.option_parser.print_usage_table
      end
      puts "\nGLOBAL OPTIONS"
      Boson::Scientist.option_command(cmd).option_parser.print_usage_table
    end
  end
end