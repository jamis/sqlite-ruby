#--
# =============================================================================
# Copyright (c) 2004, Jamis Buck (jgb3@email.byu.edu)
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
# 
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
# 
#     * The names of its contributors may not be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# =============================================================================
#++

require 'base64'
require 'sqlite_api'
require 'sqlite/pragmas'
require 'sqlite/statement'
require 'sqlite/translator'

module SQLite

  # The Database class encapsulates a single connection to a SQLite database.
  # Its usage is very straightforward:
  #
  #   require 'sqlite'
  #
  #   db = SQLite::Database.new( "data.db" )
  #
  #   db.execute( "select * from table" ) do |row|
  #     p row
  #   end
  #
  #   db.close
  #
  # It wraps the lower-level methods provides by the API module, include
  # includes the Pragmas module for access to various pragma convenience
  # methods.
  #
  # The Database class provides type translation services as well, by which
  # the SQLite data types (which are all represented as strings) may be
  # converted into their corresponding types (as defined in the schemas
  # for their tables). This translation only occurs when querying data from
  # the database--insertions and updates are all still typeless.
  #
  # Furthermore, the Database class has been designed to work well with the
  # ArrayFields module from Ara Howard. If you require the ArrayFields
  # module before performing a query, and if you have not enabled results as
  # hashes, then the results will all be indexible by field name.
  class Database
    include SQLite::Pragmas

    # Opens the database contained in the given file. This just calls #new,
    # passing 0 as the mode parameter. This returns the new Database
    # instance.
    def self.open( file_name )
      new( file_name, 0 )
    end

    # Quotes the given string, making it safe to use in an SQL statement.
    # It replaces all instances of the single-quote character with two
    # single-quote characters. The modified string is returned.
    def self.quote( string )
      string.gsub( /'/, "''" )
    end

    # Returns a string that represents the serialization of the given object.
    # The string may safely be used in an SQL statement.
    def self.encode( object )
      Base64.encode64( Marshal.dump( object ) ).strip
    end

    # Unserializes the object contained in the given string. The string must be
    # one that was returned by #encode.
    def self.decode( string )
      Marshal.load( Base64.decode64( string ) )
    end

    # Return +true+ if the string is a valid (ie, parsable) SQL statement, and
    # +false+ otherwise.
    def self.complete?( string )
      SQLite::API.complete( string )
    end

    # The low-level opaque database handle that this object wraps.
    attr_reader :handle

    # A boolean that indicates whether rows in result sets should be returned
    # as hashes or not. By default, rows are returned as arrays.
    attr_accessor :results_as_hash

    # Create a new Database object that opens the given file. The mode
    # parameter has no meaning yet, and may be omitted. If the file does not
    # exist, it will be created if possible.
    #
    # By default, the new database will return result rows as arrays
    # (#results_as_hash) and has type translation disabled (#type_translation=).
    def initialize( file_name, mode=0 )
      @handle = SQLite::API.open( file_name, mode )
      @closed = false
      @results_as_hash = false
      @type_translation = false
      @translator = nil
    end

    # Return the type translator employed by this database instance. Each
    # database instance has its own type translator; this allows for different
    # type handlers to be installed in each instance without affecting other
    # instances. Furthermore, the translators are instantiated lazily, so that
    # if a database does not use type translation, it will not be burdened by
    # the overhead of a useless type translator. (See the Translator class.)
    def translator
      @translator ||= Translator.new
    end

    # Returns +true+ if type translation is enabled for this database, or
    # +false+ otherwise.
    def type_translation
      @type_translation
    end

    # Enable or disable type translation for this database.
    def type_translation=( mode )
      @type_translation = mode
    end

    # Closes this database. No checks are done to ensure that a database is not
    # closed more than once, and closing a database more than once can be
    # catastrophic.
    def close
      SQLite::API.close( @handle )
      @closed = true
    end

    # Returns +true+ if this database instance has been closed (see #close).
    def closed?
      @closed
    end

    # Returns a Statement object representing the given SQL. This does not
    # execute the statement; it merely prepares the statement for execution.
    def prepare( sql )
      Statement.new( self, sql )
    end

    # Executes the given SQL statement. If additional parameters are given,
    # they are treated as bind variables, and are bound to the placeholders in
    # the query.
    #
    # Each placeholder must match one of the following formats:
    #
    # * <tt>?</tt>
    # * <tt>?nnn</tt>
    # * <tt>:word</tt>
    # * <tt>:word:</tt>
    #
    # where _nnn_ is an integer value indicating the index of the bind
    # variable to be bound at that position, and _word_ is an alphanumeric
    # identifier for that placeholder. For "<tt>?</tt>", an index is
    # automatically assigned of one greater than the previous index used
    # (or 1, if it is the first).
    #
    # Note that if any of the values passed to this are hashes, then the
    # key/value pairs are each bound separately, with the key being used as
    # the name of the placeholder to bind the value to.
    #
    # The block is optional. If given, it will be invoked for each row returned
    # by the query. Otherwise, any results are accumulated into an array and
    # returned wholesale.
    #
    # See also #execute2, #execute_batch and #query for additional ways of
    # executing statements.
    def execute( sql, *bind_vars )
      stmt = prepare( sql )
      stmt.bind_params( *bind_vars )
      result = stmt.execute
      begin
        if block_given?
          result.each { |row| yield row }
        else
          return result.inject( [] ) { |arr,row| arr << row; arr }
        end
      ensure
        result.close
      end
    end

    # Executes the given SQL statement, exactly as with #execute. However, the
    # first row returned (either via the block, or in the returned array) is
    # always the names of the columns. Subsequent rows correspond to the data
    # from the result set.
    #
    # Thus, even if the query itself returns no rows, this method will always
    # return at least one row--the names of the columns.
    #
    # See also #execute, #execute_batch and #query for additional ways of
    # executing statements.
    def execute2( sql, *bind_vars )
      stmt = prepare( sql )
      stmt.bind_params( *bind_vars )
      result = stmt.execute
      begin
        if block_given?
          yield result.columns
          result.each { |row| yield row }
        else
          return result.inject( [ result.columns ] ) { |arr,row| arr << row; arr }
        end
      ensure  
        result.close
      end
    end

    # Executes all SQL statements in the given string. By contrast, the other
    # means of executing queries will only execute the first statement in the
    # string, ignoring all subsequent statements. This will execute each one
    # in turn. The same bind parameters, if given, will be applied to each
    # statement.
    #
    # This always returns +nil+, making it unsuitable for queries that return
    # rows.
    def execute_batch( sql, *bind_vars )
      loop do
        stmt = prepare( sql )
        stmt.bind_params *bind_vars
        stmt.execute
        sql = stmt.remainder
        break if sql.length < 1
      end
      nil
    end

    # This does like #execute and #execute2 (binding variables and so forth),
    # but instead of yielding each row from the result set, this will yield the
    # ResultSet instance itself (q.v.). If no block is given, the ResultSet
    # instance will be returned.
    def query( sql, *bind_vars, &block ) # :yields: result_set
      stmt = prepare( sql )
      stmt.bind_params( *bind_vars )
      stmt.execute( &block )
    end

    # A convenience method for obtaining the first row of a result set, and
    # discarding all others. It is otherwise identical to #execute.
    #
    # See also #get_first_value.
    def get_first_row( sql, *bind_vars )
      execute( sql, *bind_vars ) { |row| return row }
      nil
    end

    # A convenience method for obtaining the first value of the first row of a
    # result set, and discarding all other values and rows. It is otherwise
    # identical to #execute.
    #
    # See also #get_first_row.
    def get_first_value( sql, *bind_vars )
      execute( sql, *bind_vars ) { |row| return row[0] }
      nil
    end

    # Obtains the unique row ID of the last row to be inserted by this Database
    # instance.
    def last_insert_row_id
      SQLite::API.last_insert_row_id( @handle )
    end

    # Returns the number of changes made to this database instance by the last
    # operation performed. Note that a "delete from table" without a where
    # clause will not affect this value.
    def changes
      SQLite::API.changes( @handle )
    end

    # Interrupts the currently executing operation, causing it to abort.
    def interrupt
      SQLite::API.interrupt( @handle )
    end

    # Register a busy handler with this database instance. When a requested
    # resource is busy, this handler will be invoked. If the handler returns
    # +false+, the operation will be aborted; otherwise, the resource will
    # be requested again.
    #
    # The handler will be invoked with the name of the resource that was
    # busy, and the number of times it has been retried.
    #
    # See also #busy_timeout.
    def busy_handler( &block ) # :yields: resource, retries
      SQLite::API.busy_handler( @handle, block )
    end

    # Indicates that if a request for a resource terminates because that
    # resource is busy, SQLite should wait for the indicated number of
    # milliseconds before trying again. By default, SQLite does not retry
    # busy resources. To restore the default behavior, send 0 as the
    # +ms+ parameter.
    #
    # See also #busy_handler.
    def busy_timeout( ms )
      SQLite::API.busy_timeout( @handle, ms )
    end

    # Creates a new function for use in SQL statements. It will be added as
    # +name+, with the given +arity+. (For variable arity functions, use
    # -1 for the arity.) If +type+ is non-nil, it should either be an
    # integer (indicating that the type of the function is always the
    # type of the argument at that index), or one of the symbols
    # <tt>:numeric</tt>, <tt>:text</tt>, <tt>:args</tt> (in which case
    # the function is, respectively, numeric, textual, or the same type as
    # its arguments).
    #
    # The block should accept at least one parameter--the FunctionProxy
    # instance that wraps this function invocation--and any other
    # arguments it needs (up to its arity).
    #
    # The block does not return a value directly. Instead, it will invoke
    # the FunctionProxy#set_result method on the +func+ parameter and
    # indicate the return value that way.
    #
    # Example:
    #
    #   db.create_function( "maim", 1, :text ) do |func, value|
    #     if value.nil?
    #       func.set_value nil
    #     else
    #       func.set_value value.split(//).sort.join
    #     end
    #   end
    #
    #   puts db.get_first_value( "select maim(name) from table" )
    def create_function( name, arity, type=nil, &block ) # :yields: func, *args
      case type
        when :numeric
          type = SQLite::API::NUMERIC
        when :text
          type = SQLite::API::TEXT
        when :args
          type = SQLite::API::ARGS
      end

      callback = proc do |func,*args|
        begin
          block.call( FunctionProxy.new( func ), *args )
        rescue Exception => e
          SQLite::API.set_result_error( func, "#{e.message} (#{e.class})" )
        end
      end

      SQLite::API.create_function( @handle, name, arity, callback )
      SQLite::API.function_type( @handle, name, type ) if type

      self
    end

    # Creates a new aggregate function for use in SQL statements. Aggregate
    # functions are functions that apply over every row in the result set,
    # instead of over just a single row. (A very common aggregate function
    # is the "count" function, for determining the number of rows that match
    # a query.)
    #
    # The new function will be added as +name+, with the given +arity+. (For
    # variable arity functions, use -1 for the arity.) If +type+ is non-nil,
    # it should be a value as described in #create_function.
    #
    # The +step+ parameter must be a proc object that accepts as its first
    # parameter a FunctionProxy instance (representing the function
    # invocation), with any subsequent parameters (up to the function's arity).
    # The +step+ callback will be invoked once for each row of the result set.
    #
    # The +finalize+ parameter must be a +proc+ object that accepts only a
    # single parameter, the FunctionProxy instance representing the current
    # function invocation. It should invoke FunctionProxy#set_result to
    # store the result of the function.
    #
    # Example:
    #
    #   step = proc do |func, value|
    #     func[ :total ] ||= 0
    #     func[ :total ] += ( value ? value.length : 0 )
    #   end
    #
    #   finalize = proc do |func|
    #     func.set_result( func[ :total ] || 0 )
    #   end
    #
    #   db.create_aggregate( "lengths", 1, step, finalize, :numeric )
    #
    #   puts db.get_first_value( "select lengths(name) from table" )
    #
    # See also #create_aggregate_handler for a more object-oriented approach to
    # aggregate functions.
    def create_aggregate( name, arity, step, finalize, type=nil )
      case type
        when :numeric
          type = SQLite::API::NUMERIC
        when :text
          type = SQLite::API::TEXT
        when :args
          type = SQLite::API::ARGS
      end

      step_callback = proc do |func,*args|
        ctx = SQLite::API.aggregate_context( func )
        unless ctx[:__error]
          begin
            step.call( FunctionProxy.new( func, ctx ), *args )
          rescue Exception => e
            ctx[:__error] = e
          end
        end
      end

      finalize_callback = proc do |func|
        ctx = SQLite::API.aggregate_context( func )
        unless ctx[:__error]
          begin
            finalize.call( FunctionProxy.new( func, ctx ) )
          rescue Exception => e
            SQLite::API.set_result_error( func, "#{e.message} (#{e.class})" )
          end
        else
          e = ctx[:__error]
          SQLite::API.set_result_error( func, "#{e.message} (#{e.class})" )
        end
      end

      SQLite::API.create_aggregate( @handle, name, arity,
        step_callback, finalize_callback )

      SQLite::API.function_type( @handle, name, type ) if type

      self
    end

    # This is another approach to creating an aggregate function (see
    # #create_aggregate). Instead of explicitly specifying the name,
    # callbacks, arity, and type, you specify a factory object
    # (the "handler") that knows how to obtain all of that information. The
    # handler should respond to the following messages:
    #
    # +function_type+:: corresponds to the +type+ parameter of
    #                   #create_aggregate. This is an optional message, and if
    #                   the handler does not respond to it, the function type
    #                   will not be set for this function.
    # +arity+:: corresponds to the +arity+ parameter of #create_aggregate. This
    #           message is optional, and if the handler does not respond to it,
    #           the function will have an arity of -1.
    # +name+:: this is the name of the function. The handler _must_ implement
    #          this message.
    # +new+:: this must be implemented by the handler. It should return a new
    #         instance of the object that will handle a specific invocation of
    #         the function.
    #
    # The handler instance (the object returned by the +new+ message, described
    # above), must respond to the following messages:
    #
    # +step+:: this is the method that will be called for each step of the
    #          aggregate function's evaluation. It should implement the same
    #          signature as the +step+ callback for #create_aggregate.
    # +finalize+:: this is the method that will be called to finalize the
    #              aggregate function's evaluation. It should implement the
    #              same signature as the +finalize+ callback for
    #              #create_aggregate.
    #
    # Example:
    #
    #   class LengthsAggregateHandler
    #     def self.function_type; :numeric; end
    #     def self.arity; 1; end
    #
    #     def initialize
    #       @total = 0
    #     end
    #
    #     def step( ctx, name )
    #       @total += ( name ? name.length : 0 )
    #     end
    #
    #     def finalize( ctx )
    #       ctx.set_result( @total )
    #     end
    #   end
    #
    #   db.create_aggregate_handler( LengthsAggregateHandler )
    #   puts db.get_first_value( "select lengths(name) from A" )
    def create_aggregate_handler( handler )
      type = nil
      arity = -1

      type = handler.function_type if handler.respond_to?(:function_type)
      arity = handler.arity if handler.respond_to?(:arity)
      name = handler.name

      case type
        when :numeric
          type = SQLite::API::NUMERIC
        when :text
          type = SQLite::API::TEXT
        when :args
          type = SQLite::API::ARGS
      end

      step = proc do |func,*args|
        ctx = SQLite::API.aggregate_context( func )
        unless ctx[ :__error ]
          ctx[ :handler ] ||= handler.new
          begin
            ctx[ :handler ].step( FunctionProxy.new( func, ctx ), *args )
          rescue Exception => e
            ctx[ :__error ] = e
          end
        end
      end

      finalize = proc do |func|
        ctx = SQLite::API.aggregate_context( func )
        unless ctx[ :__error ]
          ctx[ :handler ] ||= handler.new
          begin
            ctx[ :handler ].finalize( FunctionProxy.new( func, ctx ) )
          rescue Exception => e
            ctx[ :__error ] = e
          end
        end

        if ctx[ :__error ]
          e = ctx[ :__error ]
          SQLite::API.set_result_error( func, "#{e.message} (#{e.class})" )
        end
      end

      SQLite::API.create_aggregate( @handle, name, arity, step, finalize )
      SQLite::API.function_type( @handle, name, type ) if type

      self
    end

    # Begins a new transaction. Note that nested transactions are not allowed
    # by SQLite, so attempting to nest a transaction will result in a runtime
    # exception.
    #
    # If a block is given, the database instance is yielded to it, and the
    # transaction is committed when the block terminates. If the block
    # raises an exception, a rollback will be performed instead. Note that if
    # a block is given, #commit and #rollback should never be called
    # explicitly or you'll get an error when the block terminates.
    #
    # If a block is not given, it is the caller's responsibility to end the
    # transaction explicitly, either by calling #commit, or by calling
    # #rollback.
    def transaction
      execute "begin transaction"
      @transaction_active = true

      if block_given?
        abort = false
        begin
          yield self
        rescue Exception
          abort = true
          raise
        ensure
          abort and rollback or commit
        end
      end

      true
    end

    # Commits the current transaction. If there is no current transaction,
    # this will cause an error to be raised. This returns +true+, in order
    # to allow it to be used in idioms like
    # <tt>abort? and rollback or commit</tt>.
    def commit
      execute "commit transaction"
      @transaction_active = false
      true
    end

    # Rolls the current transaction back. If there is no current transaction,
    # this will cause an error to be raised. This returns +true+, in order
    # to allow it to be used in idioms like
    # <tt>abort? and rollback or commit</tt>.
    def rollback
      execute "rollback transaction"
      @transaction_active = false
      true
    end

    # Returns +true+ if there is a transaction active, and +false+ otherwise.
    def transaction_active?
      @transaction_active
    end

    # A helper class for dealing with custom functions (see #create_function,
    # #create_aggregate, and #create_aggregate_handler). It encapsulates the
    # opaque function object that represents the current invocation. It also
    # provides more convenient access to the API functions that operate on
    # the function object.
    #
    # This class will almost _always_ be instantiated indirectly, by working
    # with the create methods mentioned above.
    class FunctionProxy

      # Create a new FunctionProxy that encapsulates the given +func+ object.
      # If context is non-nil, the functions context will be set to that. If
      # it is non-nil, it must quack like a Hash. If it is nil, then none of
      # the context functions will be available.
      def initialize( func, context=nil )
        @func = func
        @context = context
      end

      # Set the result of the function to the given value. The function will
      # then return this value.
      def set_result( result )
        SQLite::API.set_result( @func, result )
      end

      # Set the result of the function to the given error message, which must
      # be a string. The function will then return that error.
      def set_error( error )
        SQLite::API.set_result_error( @func, error )
      end

      # (Only available to aggregate functions.) Returns the number of rows
      # that the aggregate has processed so far. This will include the current
      # row, and so will always return at least 1.
      def count
        ensure_aggregate!
        SQLite::API.aggregate_count( @func )
      end

      # Returns the value with the given key from the context. This is only
      # available to aggregate functions.
      def []( key )
        ensure_aggregate!
        @context[ key ]
      end

      # Sets the value with the given key in the context. This is only
      # available to aggregate functions.
      def []=( key, value )
        ensure_aggregate!
        @context[ key ] = value
      end

      # A function for performing a sanity check, to ensure that the function
      # being invoked is an aggregate function. This is implied by the
      # existence of the context variable.
      def ensure_aggregate!
        unless @context
          raise Exceptions::MisuseException, "function is not an aggregate"
        end
      end
      private :ensure_aggregate!

    end

  end

end

