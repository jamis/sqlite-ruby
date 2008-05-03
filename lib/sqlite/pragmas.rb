module SQLite

  # This module is intended for inclusion solely by the Database class. It
  # defines convenience methods for the various pragmas supported by SQLite.
  #
  # Two pragmas that have been intentionally excluded are SHOW_DATATYPES
  # and EMPTY_RESULT_SETS, since these apply only to queries that use the
  # SQLite "exec" function. The SQLite API does not employ that function,
  # preferring instead the compile/step/finalize interface.
  #
  # However, if you really must have those pragmas, you can always execute
  # a pragma as if it were an SQL statement.
  #
  # For a detailed description of these pragmas, see the SQLite documentation
  # at http://sqlite.org/lang.html#pragma.
  module Pragmas

    # Returns +true+ or +false+ depending on the value of the named pragma.
    def get_boolean_pragma( name )
      get_first_value( "PRAGMA #{name}" ) != "0"
    end
    private :get_boolean_pragma

    # Sets the given pragma to the given boolean value. The value itself
    # may be +true+ or +false+, or any other commonly used string or
    # integer that represents truth.
    def set_boolean_pragma( name, mode )
      case mode
        when String
          case mode.downcase
            when "on", "yes", "true", "y", "t": mode = "'ON'"
            when "off", "no", "false", "n", "f": mode = "'OFF'"
            else
              raise Exceptions::DatabaseException,
                "unrecognized pragma parameter #{mode.inspect}"
          end
        when true, 1
          mode = "ON"
        when false, 0, nil
          mode = "OFF"
        else
          raise Exceptions::DatabaseException,
            "unrecognized pragma parameter #{mode.inspect}"
      end

      execute( "PRAGMA #{name}=#{mode}" )
    end
    private :set_boolean_pragma

    # Requests the given pragma (and parameters), and if the block is given,
    # each row of the result set will be yielded to it. Otherwise, the results
    # are returned as an array.
    def get_query_pragma( name, *parms, &block ) # :yields: row
      if parms.empty?
        execute( "PRAGMA #{name}", &block )
      else
        args = "'" + parms.join("','") + "'"
        execute( "PRAGMA #{name}( #{args} )", &block )
      end
    end
    private :get_query_pragma

    # Return the value of the given pragma.
    def get_enum_pragma( name )
      get_first_value( "PRAGMA #{name}" )
    end
    private :get_enum_pragma

    # Set the value of the given pragma to +mode+. The +mode+ parameter must
    # conform to one of the values in the given +enum+ array. Each entry in
    # the array is another array comprised of elements in the enumeration that
    # have duplicate values. See #synchronous, #default_synchronous,
    # #temp_store, and #default_temp_store for usage examples.
    def set_enum_pragma( name, mode, enums )
      match = enums.find { |p| p.find { |i| i.to_s.downcase == mode.to_s.downcase } }
      raise Exceptions::DatabaseException,
        "unrecognized #{name} #{mode.inspect}" unless match
      execute( "PRAGMA #{name}='#{match.first.upcase}'" )
    end
    private :set_enum_pragma

    # Returns the value of the given pragma as an integer.
    def get_int_pragma( name )
      get_first_value( "PRAGMA #{name}" ).to_i
    end
    private :get_int_pragma

    # Set the value of the given pragma to the integer value of the +value+
    # parameter.
    def set_int_pragma( name, value )
      execute( "PRAGMA #{name}=#{value.to_i}" )
    end
    private :set_int_pragma

    # The enumeration of valid synchronous modes.
    SYNCHRONOUS_MODES = [ [ 'full', 2 ], [ 'normal', 1 ], [ 'off', 0 ] ]

    # The enumeration of valid temp store modes.
    TEMP_STORE_MODES  = [ [ 'default', 0 ], [ 'file', 1 ], [ 'memory', 2 ] ]

    # Does an integrity check on the database. If the check fails, a
    # SQLite::Exceptions::DatabaseException will be raised. Otherwise it
    # returns silently.
    def integrity_check
      execute( "PRAGMA integrity_check" ) do |row|
        raise Exceptions::DatabaseException, row[0] if row[0] != "ok"
      end
    end

    def cache_size
      get_int_pragma "cache_size"
    end

    def cache_size=( size )
      set_int_pragma "cache_size", size
    end

    def default_cache_size
      get_int_pragma "default_cache_size"
    end

    def default_cache_size=( size )
      set_int_pragma "default_cache_size", size
    end

    def default_synchronous
      get_enum_pragma "default_synchronous"
    end

    def default_synchronous=( mode )
      set_enum_pragma "default_synchronous", mode, SYNCHRONOUS_MODES
    end

    def synchronous
      get_enum_pragma "synchronous"
    end

    def synchronous=( mode )
      set_enum_pragma "synchronous", mode, SYNCHRONOUS_MODES
    end

    def default_temp_store
      get_enum_pragma "default_temp_store"
    end

    def default_temp_store=( mode )
      set_enum_pragma "default_temp_store", mode, TEMP_STORE_MODES
    end
  
    def temp_store
      get_enum_pragma "temp_store"
    end

    def temp_store=( mode )
      set_enum_pragma "temp_store", mode, TEMP_STORE_MODES
    end

    def full_column_names
      get_boolean_pragma "full_column_names"
    end

    def full_column_names=( mode )
      set_boolean_pragma "full_column_names", mode
    end
  
    def parser_trace
      get_boolean_pragma "parser_trace"
    end

    def parser_trace=( mode )
      set_boolean_pragma "parser_trace", mode
    end
  
    def vdbe_trace
      get_boolean_pragma "vdbe_trace"
    end

    def vdbe_trace=( mode )
      set_boolean_pragma "vdbe_trace", mode
    end

    def database_list( &block ) # :yields: row
      get_query_pragma "database_list", &block
    end

    def foreign_key_list( table, &block ) # :yields: row
      get_query_pragma "foreign_key_list", table, &block
    end

    def index_info( index, &block ) # :yields: row
      get_query_pragma "index_info", index, &block
    end

    def index_list( table, &block ) # :yields: row
      get_query_pragma "index_list", table, &block
    end

    def table_info( table, &block ) # :yields: row
      get_query_pragma "table_info", table, &block
    end
  
  end

end
