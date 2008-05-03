require 'sqlite_api'

module SQLite

  # The ResultSet object encapsulates the enumerability of a query's output.
  # It is a simple cursor over the data that the query returns. It will
  # very rarely (if ever) be instantiated directly. Instead, client's should
  # obtain a ResultSet instance via Statement#execute.
  class ResultSet
    include Enumerable

    # A trivial module for adding a +types+ accessor to an object.
    module TypesContainer
      attr_accessor :types
    end

    # A trivial module for adding a +fields+ accessor to an object.
    module FieldsContainer
      attr_accessor :fields
    end

    # An array of the column names for this result set (may be empty)
    attr_reader :columns

    # An array of the column types for this result set (may be empty)
    attr_reader :types

    # Create a new ResultSet attached to the given database, using the
    # given sql text.
    def initialize( db, sql )
      @db = db
      @sql = sql
      commence
    end

    # A convenience method for compiling the virtual machine and stepping
    # to the first row of the result set.
    def commence
      @vm, = API.compile( @db.handle, @sql )

      @current_row = API.step( @vm )

      @columns = @current_row[ :columns ]
      @types = @current_row[ :types ]

      check_eof( @current_row )
    end
    private :commence

    # A convenience method for checking for EOF.
    def check_eof( row )
      @eof = !row.has_key?( :row )
    end
    private :check_eof

    # Close the result set. Attempting to perform any operation (including
    # #close) on a closed result set will have undefined results.
    def close
      API.finalize( @vm )
    end

    # Reset the cursor, so that a result set which has reached end-of-file
    # can be rewound and reiterated. _Note_: this uses an experimental API,
    # which is subject to change. Use at your own risk.
    def reset
      API.finalize( @vm )
      commence
      @eof = false
    end

    # Query whether the cursor has reached the end of the result set or not.
    def eof?
      @eof
    end

    # Obtain the next row from the cursor. If there are no more rows to be
    # had, this will return +nil+. If type translation is active on the
    # corresponding database, the values in the row will be translated
    # according to their types.
    #
    # The returned value will be an array, unless Database#results_as_hash has
    # been set to +true+, in which case the returned value will be a hash.
    #
    # For arrays, the column names are accessible via the +fields+ property,
    # and the column types are accessible via the +types+ property.
    #
    # For hashes, the column names are the keys of the hash, and the column
    # types are accessible via the +types+ property.
    def next
      return nil if @eof

      if @current_row
        result, @current_row = @current_row, nil
      else
        result = API.step( @vm )
        check_eof( result )
      end

      unless @eof
        row = result[:row]

        if @db.type_translation
          row = @types.zip( row ).map do |type, value|
            @db.translator.translate( type, value )
          end
        end

        if @db.results_as_hash
          new_row = Hash[ *( @columns.zip( row ).flatten ) ]
          row.each_with_index { |value,idx| new_row[idx] = value }
          row = new_row
        else
          row.extend FieldsContainer unless row.respond_to?(:fields)
          row.fields = @columns
        end

        row.extend TypesContainer
        row.types = @types

        return row
      end

      nil
    end

    # Required by the Enumerable mixin. Provides an internal iterator over the
    # rows of the result set.
    def each
      while row=self.next
        yield row
      end
    end

  end

end
