# This is a modified version of Daniel Berger's Getopt::Long class,
# licensed under Ruby's license.

module Boson
  # Simple Hash with indifferent access
  class IndifferentAccessHash < ::Hash
    def initialize(hash)
      super()
      update hash.each {|k,v| hash[convert_key(k)] = hash.delete(k) }
    end

    def [](key)
      super convert_key(key)
    end

    def []=(key, value)
      super convert_key(key), value
    end

    def values_at(*indices)
      indices.collect { |key| self[convert_key(key)] }
    end

    protected
      def convert_key(key)
        key.kind_of?(String) ? key.to_sym : key
      end
  end

  class OptionParser
    class Error < StandardError; end

    NUMERIC     = /(\d*\.\d+|\d+)/
    LONG_RE     = /^(--\w+[-\w+]*)$/
    SHORT_RE    = /^(-[a-z])$/i
    EQ_RE       = /^(--\w+[-\w+]*|-[a-z])=(.*)$/i
    SHORT_SQ_RE = /^-([a-z]{2,})$/i # Allow either -x -v or -xv style for single char args
    SHORT_NUM   = /^(-[a-z])#{NUMERIC}$/i
    
    attr_reader :leading_non_opts, :trailing_non_opts, :shorts
    
    def non_opts
      leading_non_opts + trailing_non_opts
    end

    # Takes an array of switches. Each array consists of up to three
    # elements that indicate the name and type of switch. Returns a hash
    # containing each switch name, minus the '-', as a key. The value
    # for each key depends on the type of switch and/or the value provided
    # by the user.
    #
    # The long switch _must_ be provided. The short switch defaults to the
    # first letter of the short switch. The default type is :boolean.
    #
    # Example:
    #
    #   opts = Boson::OptionParser.new(
    #      "--debug" => true,
    #      ["--verbose", "-v"] => true,
    #      ["--level", "-l"] => :numeric
    #   ).parse(args)
    #
    def initialize(switches)
      @defaults = {}
      @shorts = {}
      
      @leading_non_opts, @trailing_non_opts = [], []

      @switches = switches.inject({}) do |mem, (name, type)|
        if name.is_a?(Array)
          name, *shorts = name
        else
          name = name.to_s
          shorts = []
        end
        # we need both nice and dasherized form of switch name
        if name.index('-') == 0
          nice_name = undasherize name
        else
          nice_name = name
          name = dasherize name
        end
        # if there are no shortcuts specified, generate one using the first character
        shorts << "-" + nice_name[0,1] if shorts.empty? and nice_name.length > 1
        shorts.each { |short| @shorts[short] = name }
        
        # normalize type
        case type
        when TrueClass
          @defaults[nice_name] = true
          type = :boolean
        when FalseClass
          @defaults[nice_name] = false
          type = :boolean
        when String
          @defaults[nice_name] = type
          type = :string
        when Numeric
          @defaults[nice_name] = type
          type = :numeric
        end
        
        mem[name] = type
        mem
      end
      
      # remove shortcuts that happen to coincide with any of the main switches
      @shorts.keys.each do |short|
        @shorts.delete(short) if @switches.key?(short)
      end
    end

    def parse(args, options={})
      @args = args
      # start with defaults
      hash = IndifferentAccessHash.new @defaults
      
      @leading_non_opts = []
      unless options[:opts_before_args]
        @leading_non_opts << shift until current_is_option? || @args.empty?
      end

      while current_is_option?
        case shift
        when SHORT_SQ_RE
          unshift $1.split('').map { |f| "-#{f}" }
          next
        when EQ_RE, SHORT_NUM
          unshift $2
          switch = $1
        when LONG_RE, SHORT_RE
          switch = $1
        end
        
        switch    = normalize_switch(switch)
        nice_name = undasherize(switch).to_sym
        type      = switch_type(switch)

        case type
        when :required
          assert_value!(nice_name)
          raise Error, "cannot pass '#{peek}' as an argument to option '#{nice_name}'" if valid?(peek)
          hash[nice_name] = shift
        when :string
          hash[nice_name] = (peek.nil? || valid?(peek)) ? '' : shift
        when :boolean
          if !@switches.key?(switch) && nice_name.to_s =~ /^no-(\w+)$/
            hash[$1] = false
          else
            hash[nice_name] = true
          end
          
        when :numeric
          assert_value!(nice_name)
          unless peek =~ NUMERIC and $& == peek
            raise Error, "expected numeric value for option '#{nice_name}'; got #{peek.inspect}"
          end
          hash[nice_name] = $&.index('.') ? shift.to_f : shift.to_i
        end
      end
      
      @trailing_non_opts = @args
      check_required! hash
      delete_invalid_opts if options[:delete_invalid_opts]
      hash
    end

    def delete_invalid_opts
      [@leading_non_opts, @trailing_non_opts].each do |args|
        args.delete_if {|e|
          invalid = e.to_s[/^-/]
          $stderr.puts "Invalid option '#{e}'" if invalid
          invalid
        }
      end
    end
    
    def formatted_usage
      return "" if @switches.empty?
      @switches.map do |opt, type|
        case type
        when :boolean
          "[#{opt}]"
        when :required
          opt + "=" + opt.gsub(/\-/, "").upcase
        else
          sample = @defaults[undasherize(opt)]
          sample ||= case type
            when :string then undasherize(opt).gsub(/\-/, "_").upcase
            when :numeric  then "N"
            end
          "[" + opt + "=" + sample.to_s + "]"
        end
      end.join(" ")
    end
    
    alias :to_s :formatted_usage

    private
    
    def assert_value!(nice_name)
      raise Error, "no value provided for option '#{nice_name}'" if peek.nil?
    end
    
    def undasherize(str)
      str.sub(/^-{1,2}/, '')
    end
    
    def dasherize(str)
      (str.length > 1 ? "--" : "-") + str
    end
    
    def peek
      @args.first
    end

    def shift
      @args.shift
    end

    def unshift(arg)
      unless arg.kind_of?(Array)
        @args.unshift(arg)
      else
        @args = arg + @args
      end
    end
    
    def valid?(arg)
      if arg.to_s =~ /^--no-(\w+)$/
        @switches.key?(arg) or (@switches["--#{$1}"] == :boolean)
      else
        @switches.key?(arg) or @shorts.key?(arg)
      end
    end

    def current_is_option?
      case peek
      when LONG_RE, SHORT_RE, EQ_RE, SHORT_NUM
        valid?($1)
      when SHORT_SQ_RE
        $1.split('').any? { |f| valid?("-#{f}") }
      end
    end
    
    def normalize_switch(switch)
      @shorts.key?(switch) ? @shorts[switch] : switch
    end
    
    def switch_type(switch)
      if switch =~ /^--no-(\w+)$/
        @switches[switch] || @switches["--#{$1}"]
      else
        @switches[switch]
      end
    end
    
    def check_required!(hash)
      for name, type in @switches
        if type == :required and !hash[undasherize(name)]
          raise Error, "no value provided for required argument '#{name}'"
        end
      end
    end
  end
end