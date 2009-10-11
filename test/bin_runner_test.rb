require File.join(File.dirname(__FILE__), 'test_helper')
require 'boson/runners/bin_runner'

module Boson
  class BinRunnerTest < Test::Unit::TestCase
    def start(*args)
      Hirb.stubs(:enable)
      BinRunner.start(args)
    end

    before(:each) {|e|
      Boson::BinRunner.instance_variables.each {|e| Boson::BinRunner.instance_variable_set(e, nil)}
    }
    context "at commandline" do
      before(:all) { reset }

      test "no arguments prints usage" do
        capture_stdout { start }.should =~ /^boson/
      end

      test "invalid option value prints error" do
        capture_stderr { start("-l") }.should =~ /Error:/
      end

      test "help option but no arguments prints usage" do
        capture_stdout { start '-h' }.should =~ /^boson/
      end

      test "help option and command prints help" do
        capture_stdout { start('-h', 'commands') } =~ /^commands/
      end

      test "load option loads libraries" do
        Manager.expects(:load).with {|*args| args[0][0].is_a?(Module) ? true : args[0][0] == 'blah'}.times(2)
        BinRunner.stubs(:execute_command)
        start('-l', 'blah', 'libraries')
      end

      test "console option starts irb" do
        ConsoleRunner.expects(:start)
        Util.expects(:which).returns("/usr/bin/irb")
        Kernel.expects(:load).with("/usr/bin/irb")
        start("--console")
      end

      test "console option but no irb found prints error" do
        ConsoleRunner.expects(:start)
        Util.expects(:which).returns(nil)
        capture_stderr { start("--console") }.should =~ /Console not found/
      end

      test "execute option executes string" do
        BinRunner.expects(:define_autoloader)
        capture_stdout { start("-e", "p 1 + 1") }.should == "2\n"
      end

      test "execute option errors are caught" do
        capture_stderr { start("-e", "raise 'blah'") }.should =~ /^Error:/
      end

      test "command and too many arguments prints error" do
        capture_stdout { start('commands','1','2','3') }.should =~ /'commands'.*incorrect/
      end

      test "failed subcommand prints error and not command not found" do
        BinRunner.expects(:execute_command).raises("bling")
        capture_stderr { start("commands.blah") }.should =~ /Error: bling/
      end

      test "undiscovered command prints error" do
         BinRunner.expects(:load_command_by_index).returns(false)
        capture_stderr { start('blah') }.should =~ /Error.*not found/
      end

      test "basic command executes" do
        BinRunner.expects(:init).returns(true)
        BinRunner.stubs(:render_output)
        Boson.main_object.expects(:send).with('kick','it')
        start 'kick','it'
      end

      test "sub command executes" do
        obj = Object.new
        Boson.main_object.extend Module.new { def phone; Struct.new(:home).new('done'); end }
        BinRunner.expects(:init).returns(true)
        BinRunner.expects(:render_output).with('done')
        start 'phone.home'
      end

      test "bin_defaults config loads by default" do
        defaults = Boson::Runner.default_libraries + ['yo']
        with_config(:bin_defaults=>['yo']) do
          Manager.expects(:load).with {|*args| args[0] == defaults }
          capture_stderr { start 'blah' }
        end
      end
    end

    context "load_command_by_index" do
      test "with index option, no existing index and core command updates index and prints index message" do
        Manager.expects(:load).with {|*args| args[0][0].is_a?(Module) ? true : args[0] == Runner.all_libraries }.at_least(1)
        Index.expects(:exists?).returns(false)
        Index.expects(:write)
        capture_stdout { start("--index", "libraries") }.should =~ /Generating index/
      end

      test "with index option, existing index and core command updates incremental index" do
        Index.expects(:changed_libraries).returns(['changed'])
        Manager.expects(:load).with {|*args| args[0][0].is_a?(Module) ? true : args[0] == ['changed'] }.at_least(1)
        Index.expects(:exists?).returns(true)
        Index.expects(:write)
        capture_stdout { start("--index", "libraries")}.should =~ /Indexing.*changed/
      end

      test "with core command updates index and doesn't print index message" do
        Index.expects(:write)
        Boson.main_object.expects(:send).with('libraries')
        capture_stdout { start 'libraries'}.should_not =~ /index/i
      end

      test "with non-core command finding library doesn't update index" do
        Index.expects(:find_library).returns('sweet_lib')
        Manager.expects(:load).with {|*args| args[0].is_a?(String) ? args[0] == 'sweet_lib' : true}.at_least(1)
        Index.expects(:update).never
        capture_stderr { start("sweet") }.should =~ /sweet/
      end

      test "with non-core command not finding library, does update index" do
        Index.expects(:find_library).returns(nil, 'sweet_lib').times(2)
        Manager.expects(:load).with {|*args| args[0].is_a?(String) ? args[0] == 'sweet_lib' : true}.at_least(1)
        Index.expects(:update).returns(true)
        capture_stderr { start("sweet") }.should =~ /sweet/
      end
    end

    test "parse_args only translates options before command" do
      BinRunner.parse_args(['-v', 'com', '-v']).should == ["com", {:verbose=>true}, ['-v']]
      BinRunner.parse_args(['com', '-v']).should == ["com", {}, ['-v']]
    end
  end
end