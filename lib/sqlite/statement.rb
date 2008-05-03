require 'sqlite_api'
require 'sqlite/resultset'
require 'sqlite/parsed_statement'

module SQLite

  # A statement represents a prepared-but-unexecuted SQL query. It will rarely
  # (if ever) be instantiated directly by a client, and is most often obtained
  # via the Database#prepare method.
  class Statement

    # This is any text that followed the first valid SQL statement in the text
    # with which the statement was initialized. If there was no trailing text,
    # this will be the empty string.
    attr_reader :remainder

    # Create a new statement attached to the given Database instance, and which
    # encapsulates the given SQL text. If the text contains more than one
    # statement (i.e., separated by semicolons), then the #remainder property
    # will be set to the trailing text.
    def initialize( db, sql )
      @db = db
      @statement = ParsedStatement.new( sql )
      @remainder = @statement.trailing.strip
      @sql = @statement.to_s
    end

    # Binds the given variables to the corresponding placeholders in the SQL
    # text.
    #
    # See Database#execute for a description of the valid placeholder
    # syntaxes.
    #
    # Example:
    #
    #   stmt = db.prepare( "select * from table where a=? and b=?" )
    #   stmt.bind_params( 15, "hello" )
    #
    # See also #execute, #bind_param, Statement#bind_param, and
    # Statement#bind_params.
    def bind_params( *bind_vars )
      @statement.bind_params( *bind_vars )
    end

    # Binds value to the named (or positional) placeholder. If +param+ is a
    # Fixnum, it is treated as an index for a positional placeholder.
    # Otherwise it is used as the name of the placeholder to bind to.
    #
    # See also #bind_params.
    def bind_param( param, value )
      @statement.bind_param( param, value )
    end

    # Execute the statement. This creates a new ResultSet object for the
    # statement's virtual machine. If a block was given, the new ResultSet will
    # be yielded to it and then closed; otherwise, the ResultSet will be
    # returned. In that case, it is the client's responsibility to close the
    # ResultSet.
    #
    # Any parameters will be bound to the statement using #bind_params.
    #
    # Example:
    #
    #   stmt = db.prepare( "select * from table" )
    #   stmt.execute do |result|
    #     ...
    #   end
    #
    # See also #bind_params, #execute!.
    def execute( *bind_vars )
      bind_params *bind_vars unless bind_vars.empty?
      results = ResultSet.new( @db, @statement.to_s )

      if block_given?
        begin
          yield results
        ensure
          results.close
        end
      else
        return results
      end
    end

    # Execute the statement. If no block was given, this returns an array of
    # rows returned by executing the statement. Otherwise, each row will be
    # yielded to the block and then closed.
    #
    # Any parameters will be bound to the statement using #bind_params.
    #
    # Example:
    #
    #   stmt = db.prepare( "select * from table" )
    #   stmt.execute! do |row|
    #     ...
    #   end
    #
    # See also #bind_params, #execute.
    def execute!( *bind_vars )
      result = execute( *bind_vars )
      rows = [] unless block_given?
      while row = result.next
        if block_given?
          yield row
        else
          rows << row
        end
      end
      rows
    ensure
      result.close if result
    end

    # Return an array of the column names for this statement. Note that this
    # may execute the statement in order to obtain the metadata; this makes it
    # a (potentially) expensive operation.
    def columns
      get_metadata unless @columns
      return @columns
    end

    # Return an array of the data types for each column in this statement. Note
    # that this may execute the statement in order to obtain the metadata; this
    # makes it a (potentially) expensive operation.
    def types
      get_metadata unless @types
      return @types
    end

    # A convenience method for obtaining the metadata about the query. Note
    # that this will actually execute the SQL, which means it can be a
    # (potentially) expensive operation.
    def get_metadata
      vm, rest = API.compile( @db.handle, @statement.to_s )
      result = API.step( vm )
      API.finalize( vm )

      @columns = result[:columns]
      @types = result[:types]
    end
    private :get_metadata

  end

end
