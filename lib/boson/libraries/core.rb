module Boson
  module Libraries
    module Core
      def commands(*args)
        puts ::Hirb::Helpers::Table.render(Boson.commands.search(*args).map {|e| e.to_hash}, :fields=>[:name, :lib, :alias, :description])
      end

      def libraries(query=nil)
        puts ::Hirb::Helpers::Table.render(Boson.libraries.search(query, :loaded=>true).map {|e| e.to_hash},
         :fields=>[:name, :loaded, :commands, :gems], :filters=>{:gems=>lambda {|e| e.join(',')}, :commands=>:size} )
      end
    
      def load_library(library, options={})
        Boson::Loader.load_library(library, {:verbose=>true}.merge!(options))
      end

      def reload_library(name, options={})
        Boson::Loader.reload_library(name, {:verbose=>true}.merge!(options))
      end
    end
  end
end