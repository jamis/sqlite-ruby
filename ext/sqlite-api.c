#include <stdarg.h>   /* for variable-arity methods */
#include <stdlib.h>   /* malloc() */
#include <sqlite.h>   /* for the SQLite API */
#include "ruby.h"     /* for the Ruby API */

/* TODO: methods not yet implemented:
 *   sqlite_set_authorizer
 *   sqlite_trace
 *   sqlite_encode_binary
 *   sqlite_decode_binary
 *
 *   sqlite_open_encrypted
 *   sqlite_rekey */

/*>=-----------------------------------------------------------------------=<*
 * MACROS
 * ------------------------------------------------------------------------
 * These are for performing frequently requested tasks.
 *>=-----------------------------------------------------------------------=<*/

#define GetDB(var,val) \
  Data_Get_Struct( val, sqlite, var ); \
  if( var == NULL ) { \
    static_raise_db_error( -1, "attempt to access a closed database" ); \
  }

#define GetVM(var,val) \
  Data_Get_Struct( val, sqlite_vm, var ); \
  if( var == NULL ) { \
    return Qnil; \
  }

#define GetFunc(var,val) \
  Data_Get_Struct( val, sqlite_func, var )

/* special macro for helping RDoc to ignore "section"-level comments. */
#define NO_RDOC

/*>=-----------------------------------------------------------------------=<*
 * CONSTANTS
 * ------------------------------------------------------------------------
 * These are constants used internally by the extension library.
 *>=-----------------------------------------------------------------------=<*/
NO_RDOC

static VALUE mSQLite;
static VALUE mAPI;
static VALUE mExceptions;

static VALUE DatabaseException;

static ID    idRow;
static ID    idColumns;
static ID    idTypes;
static ID    idCall;

static struct {
  const char *name;
  VALUE object;
} g_sqlite_exceptions[] = {
  { "OK", 0 },
  { "SQL", 0 },
  { "Internal", 0 },
  { "Permissions", 0 },
  { "Abort", 0 },
  { "Busy", 0 },
  { "Locked", 0 },
  { "OutOfMemory", 0 },
  { "ReadOnly", 0 },
  { "Interrupt", 0 },
  { "IOError", 0 },
  { "Corrupt", 0 },
  { "NotFound", 0 },
  { "Full", 0 },
  { "CantOpen", 0 },
  { "Protocol", 0 },
  { "Empty", 0 },
  { "SchemaChanged", 0 },
  { "TooBig", 0 },
  { "Constraint", 0 },
  { "Mismatch", 0 },
  { "Misuse", 0 },
  { "UnsupportedOSFeature", 0 },
  { "Authorization", 0 },
  { "Format", 0 },
  { "Range", 0 },
  { "NotADatabase", 0 },
  { NULL, 0 }
};

#ifdef DONT_DEFINE___RDOC_PURPOSES_ONLY
  x = rb_define_class_under( mExceptions, "SQLException", DatabaseException )
  x = rb_define_class_under( mExceptions, "InternalException", DatabaseException )
  x = rb_define_class_under( mExceptions, "PermissionsException", DatabaseException )
  x = rb_define_class_under( mExceptions, "AbortException", DatabaseException )
  x = rb_define_class_under( mExceptions, "BusyException", DatabaseException )
  x = rb_define_class_under( mExceptions, "LockedException", DatabaseException )
  x = rb_define_class_under( mExceptions, "OutOfMemoryException", DatabaseException )
  x = rb_define_class_under( mExceptions, "ReadOnlyException", DatabaseException )
  x = rb_define_class_under( mExceptions, "InterruptException", DatabaseException )
  x = rb_define_class_under( mExceptions, "IOErrorException", DatabaseException )
  x = rb_define_class_under( mExceptions, "CorruptException", DatabaseException )
  x = rb_define_class_under( mExceptions, "NotFoundException", DatabaseException )
  x = rb_define_class_under( mExceptions, "FullException", DatabaseException )
  x = rb_define_class_under( mExceptions, "CantOpenException", DatabaseException )
  x = rb_define_class_under( mExceptions, "ProtocolException", DatabaseException )
  x = rb_define_class_under( mExceptions, "EmptyException", DatabaseException )
  x = rb_define_class_under( mExceptions, "SchemaChangedException", DatabaseException )
  x = rb_define_class_under( mExceptions, "TooBigException", DatabaseException )
  x = rb_define_class_under( mExceptions, "ConstraintException", DatabaseException )
  x = rb_define_class_under( mExceptions, "MismatchException", DatabaseException )
  x = rb_define_class_under( mExceptions, "MisuseException", DatabaseException )
  x = rb_define_class_under( mExceptions, "UnsupportedOSFeatureException", DatabaseException )
  x = rb_define_class_under( mExceptions, "AuthorizationException", DatabaseException )
  x = rb_define_class_under( mExceptions, "FormatException", DatabaseException )
  x = rb_define_class_under( mExceptions, "RangeException", DatabaseException )
  x = rb_define_class_under( mExceptions, "NotADatabaseException", DatabaseException )
#endif

/*>=-----------------------------------------------------------------------=<*
 * PUBLIC FUNCTION DECLARATIONS
 * ------------------------------------------------------------------------
 * These functions are exported, for Ruby to access directly.
 *>=-----------------------------------------------------------------------=<*/
NO_RDOC

void Init_sqlite_api();

/*>=-----------------------------------------------------------------------=<*
 * PRIVATE METHOD DECLARATIONS
 * ------------------------------------------------------------------------
 * These are the method hooks that will be used in this extension library.
 *>=-----------------------------------------------------------------------=<*/
NO_RDOC

static VALUE
static_api_open( VALUE module, VALUE file_name, VALUE mode );

static VALUE
static_api_close( VALUE module, VALUE db );

static VALUE
static_api_compile( VALUE module, VALUE db, VALUE sql );

static VALUE
static_api_finalize( VALUE module, VALUE vm );

static VALUE
static_api_last_insert_row_id( VALUE module, VALUE db );

static VALUE
static_api_changes( VALUE module, VALUE db );

static VALUE
static_api_interrupt( VALUE module, VALUE db );

static VALUE
static_api_complete( VALUE module, VALUE sql );

static VALUE
static_api_busy_handler( VALUE module, VALUE db, VALUE handler );

static VALUE
static_api_busy_timeout( VALUE module, VALUE db, VALUE ms );

static VALUE
static_api_create_function( VALUE module, VALUE db, VALUE name, VALUE n,
  VALUE proc );

static VALUE
static_api_create_aggregate( VALUE module, VALUE db, VALUE name, VALUE n,
  VALUE step, VALUE finalize );

static VALUE
static_api_function_type( VALUE module, VALUE db, VALUE name, VALUE type );

static VALUE
static_api_set_result( VALUE module, VALUE func, VALUE result );

static VALUE
static_api_set_result_error( VALUE module, VALUE func, VALUE string );

static VALUE
static_api_aggregate_context( VALUE module, VALUE func );

static VALUE
static_api_aggregate_count( VALUE module, VALUE func );

/*>=-----------------------------------------------------------------------=<*
 * PRIVATE FUNCTION DECLARATIONS
 * ------------------------------------------------------------------------
 * These are the functions that will be used in this extension library.
 *>=-----------------------------------------------------------------------=<*/
NO_RDOC

static void
static_configure_exception_classes();

static void
static_raise_db_error( int code, char *msg, ... );

static void
static_raise_db_error2( int code, char **msg );

static void
static_free_vm( sqlite_vm *vm );

static int
static_busy_handler( void* cookie, const char *entity, int times );

static void
static_function_callback( sqlite_func *func, int argc, const char **argv );

static void
static_aggregate_finalize_callback( sqlite_func *func );

/*>=-----------------------------------------------------------------------=<*
 * PRIVATE METHOD IMPLEMENTATIONS
 * ------------------------------------------------------------------------
 * Here are the implementations of the methods declared in the previous
 * section.
 *>=-----------------------------------------------------------------------=<*/
NO_RDOC

/**
 * call-seq:
 *     open( file_name, mode ) -> db
 *
 * Open the named database file. Returns the opaque handle.
 */
static VALUE
static_api_open( VALUE module, VALUE file_name, VALUE mode )
{
  char   *s_file_name;
  char   *errmsg;
  int     i_mode;
  sqlite *db;

  Check_Type( file_name, T_STRING );
  Check_Type( mode,      T_FIXNUM );

  s_file_name = STR2CSTR( file_name );
  i_mode      = FIX2INT( mode );

  db = sqlite_open( s_file_name, i_mode, &errmsg );
  if( db == NULL )
  {
    static_raise_db_error2( -1, &errmsg );
    /* "raise" does not return */
  }

  return Data_Wrap_Struct( rb_cData, NULL, sqlite_close, db );
}

/**
 * call-seq:
 *     close( db )
 *
 * Closes the given opaque database handle. The handle _must_ be one that was
 * returned by a call to #open.
 */
static VALUE
static_api_close( VALUE module, VALUE db )
{
  sqlite *handle;

  /* FIXME: should this be executed atomically? */
  GetDB( handle, db );
  sqlite_close( handle );

  /* don't need to free the handle anymore */
  RDATA(db)->dfree = NULL;
  RDATA(db)->data = NULL;

  return Qnil;
}

/**
 * call-seq:
 *     compile( db, sql ) -> [ vm, remainder ]
 *
 * Compiles the given SQL statement and returns a new virtual machine handle
 * for executing it. Returns a tuple: [ vm, remainder ], where +remainder+ is
 * any text that follows the first complete SQL statement in the +sql+
 * parameter.
 */
static VALUE
static_api_compile( VALUE module, VALUE db, VALUE sql )
{
  sqlite     *handle;
  sqlite_vm  *vm;
  char       *errmsg;
  const char *sql_tail;
  int         result;
  VALUE       tuple;

  GetDB( handle, db );
  Check_Type( sql, T_STRING );

  result = sqlite_compile( handle,
                           STR2CSTR( sql ),
                           &sql_tail,
                           &vm,
                           &errmsg );

  if( result != SQLITE_OK )
  {
    static_raise_db_error2( result, &errmsg );
    /* "raise" does not return */
  }

  tuple = rb_ary_new();
  rb_ary_push( tuple, Data_Wrap_Struct( rb_cData, NULL, static_free_vm, vm ) );
  rb_ary_push( tuple, rb_str_new2( sql_tail ) );

  return tuple;
}

/**
 * call-seq:
 *     step( vm ) -> hash | nil
 *
 * Steps through a single result for the given virtual machine. Returns a
 * Hash object. If there was a valid row returned, the hash will contain
 * a <tt>:row</tt> key, which maps to an array of values for that row.
 * In addition, the hash will (nearly) always contain a <tt>:columns</tt>
 * key (naming the columns in the result) and a <tt>:types</tt> key
 * (giving the data types for each column).
 *
 * This will return +nil+ if there was an error previously.
 */
static VALUE
static_api_step( VALUE module, VALUE vm )
{
  sqlite_vm   *vm_ptr;
  const char **values;
  const char **metadata;
  int          columns;
  int          result;
  int          index;
  VALUE        hash;
  VALUE        value;

  GetVM( vm_ptr, vm );
  hash = rb_hash_new();

  result = sqlite_step( vm_ptr,
                        &columns,
                        &values,
                        &metadata );

  switch( result )
  {
    case SQLITE_BUSY:
      static_raise_db_error( result, "busy in step" );

    case SQLITE_ROW:
      value = rb_ary_new2( columns );
      for( index = 0; index < columns; index++ )
      {
        VALUE entry = Qnil;

        if( values[index] != NULL )
          entry = rb_str_new2( values[index] );

        rb_ary_store( value, index, entry  );
      }
      rb_hash_aset( hash, ID2SYM(idRow), value );
      
    case SQLITE_DONE:
      value = rb_ivar_get( vm, idColumns );

      if( value == Qnil )
      {
        value = rb_ary_new2( columns );
        for( index = 0; index < columns; index++ )
        {
          rb_ary_store( value, index, rb_str_new2( metadata[ index ] ) );
        }
        rb_ivar_set( vm, idColumns, value );
      }

      rb_hash_aset( hash, ID2SYM(idColumns), value );

      value = rb_ivar_get( vm, idTypes );

      if( value == Qnil )
      {
        value = rb_ary_new2( columns );
        for( index = 0; index < columns; index++ )
        {
          VALUE item = Qnil;
          if( metadata[ index+columns ] )
            item = rb_str_new2( metadata[ index+columns ] );
          rb_ary_store( value, index, item );
        }
        rb_ivar_set( vm, idTypes, value );
      }

      rb_hash_aset( hash, ID2SYM(idTypes), value );
      break;

    case SQLITE_ERROR:
    case SQLITE_MISUSE:
      {
        char *msg = NULL;
        sqlite_finalize( vm_ptr, &msg );
        RDATA(vm)->dfree = NULL;
        RDATA(vm)->data = NULL;
        static_raise_db_error2( result, &msg );
      }
      /* "raise" doesn't return */

    default:
      static_raise_db_error( -1, "[BUG] unknown result %d from sqlite_step",
        result );
      /* "raise" doesn't return */
  }

  return hash;
}

/**
 * call-seq:
 *     finalize( vm ) -> nil
 *
 * Destroys the given virtual machine and releases any associated memory. Once
 * finalized, the VM should not be used.
 */
static VALUE
static_api_finalize( VALUE module, VALUE vm )
{
  sqlite_vm *vm_ptr;
  int        result;
  char      *errmsg;

  /* FIXME: should this be executed atomically? */
  GetVM( vm_ptr, vm );

  result = sqlite_finalize( vm_ptr, &errmsg );
  if( result != SQLITE_OK )
  {
    static_raise_db_error2( result, &errmsg );
    /* "raise" does not return */
  }

  /* don't need to free the handle anymore */
  RDATA(vm)->dfree = NULL;
  RDATA(vm)->data = NULL;

  return Qnil;
}

/**
 * call-seq:
 *     last_insert_row_id( db ) -> fixnum
 *
 * Returns the unique row ID of the last insert operation.
 */
static VALUE
static_api_last_insert_row_id( VALUE module, VALUE db )
{
  sqlite *handle;

  GetDB( handle, db );

  return INT2FIX( sqlite_last_insert_rowid( handle ) );
}

/**
 * call-seq:
 *     changes( db ) -> fixnum
 *
 * Returns the number of changed rows affected by the last operation.
 * (Note: doing a "delete from table" without a where clause does not affect
 * the result of this method--see the documentation for SQLite itself for
 * the reason behind this.)
 */
static VALUE
static_api_changes( VALUE module, VALUE db )
{
  sqlite *handle;

  GetDB( handle, db );

  return INT2FIX( sqlite_changes( handle ) );
}

/**
 * call-seq:
 *     interrupt( db ) -> nil
 *
 * Interrupts the currently executing operation.
 */
static VALUE
static_api_interrupt( VALUE module, VALUE db )
{
  sqlite *handle;

  GetDB( handle, db );
  sqlite_interrupt( handle );

  return Qnil;
}

/**
 * call-seq:
 *     complete( sql ) -> true | false
 *
 * Returns +true+ if the given SQL text is complete (parsable), and
 * +false+ otherwise.
 */
static VALUE
static_api_complete( VALUE module, VALUE sql )
{
  Check_Type( sql, T_STRING );
  return ( sqlite_complete( STR2CSTR( sql ) ) ? Qtrue : Qfalse );
}

/**
 * call-seq:
 *     busy_handler( db, handler ) -> nil
 *
 * Installs a callback to be invoked whenever a request cannot be honored
 * because a database is busy. The handler should take two parameters: a
 * string naming the resource that was being accessed, and an integer indicating
 * how many times the current request has failed due to the resource being busy.
 *
 * If the handler returns +false+, the operation will be aborted, with a
 * SQLite::BusyException being raised. Otherwise, SQLite will attempt to
 * access the resource again.
 *
 * See #busy_timeout for an easier way to manage the common case.
 */
static VALUE
static_api_busy_handler( VALUE module, VALUE db, VALUE handler )
{
  sqlite *handle;

  GetDB( handle, db );
  if( handler == Qnil )
  {
    sqlite_busy_handler( handle, NULL, NULL );
  }
  else
  {
    if( !rb_obj_is_kind_of( handler, rb_cProc ) )
    {
      rb_raise( rb_eArgError, "handler must be a proc" );
    }

    sqlite_busy_handler( handle, static_busy_handler, (void*)handler );
  }

  return Qnil;
}

/**
 * call-seq:
 *     busy_timeout( db, ms ) -> nil
 *
 * Specifies the number of milliseconds that SQLite should wait before retrying
 * to access a busy resource. Specifying zero milliseconds restores the default
 * behavior.
 */
static VALUE
static_api_busy_timeout( VALUE module, VALUE db, VALUE ms )
{
  sqlite *handle;

  GetDB( handle, db );
  Check_Type( ms, T_FIXNUM );

  sqlite_busy_timeout( handle, FIX2INT( ms ) );

  return Qnil;
}

/**
 * call-seq:
 *     create_function( db, name, args, proc ) -> nil
 *
 * Defines a new function that may be invoked from within an SQL
 * statement. The +args+ parameter specifies how many arguments the function
 * expects--use -1 to specify variable arity. The +proc+ parameter must be
 * a proc that expects +args+ + 1 parameters, with the first parameter
 * being an opaque handle to the function object itself:
 *
 *   proc do |func, *args|
 *     ...
 *   end
 *
 * The function object is used when calling the #set_result and
 * #set_result_error methods.
 */
static VALUE
static_api_create_function( VALUE module, VALUE db, VALUE name, VALUE n,
  VALUE proc )
{
  sqlite *handle;
  int     result;

  GetDB( handle, db );
  Check_Type( name, T_STRING );
  Check_Type( n, T_FIXNUM );
  if( !rb_obj_is_kind_of( proc, rb_cProc ) )
  {
    rb_raise( rb_eArgError, "handler must be a proc" );
  }

  result = sqlite_create_function( handle,
              StringValueCStr(name),
              FIX2INT(n),
              static_function_callback,
              (void*)proc );

  if( result != SQLITE_OK )
  {
    static_raise_db_error( result, "create function %s(%d)",
      StringValueCStr(name), FIX2INT(n) );
    /* "raise" does not return */
  }

  return Qnil;
}

/**
 * call-seq:
 *     create_aggregate( db, name, args, step, finalize ) -> nil
 *
 * Defines a new aggregate function that may be invoked from within an SQL
 * statement. The +args+ parameter specifies how many arguments the function
 * expects--use -1 to specify variable arity.
 *
 * The +step+ parameter specifies a proc object that will be invoked for each
 * row that the function processes. It should accept an opaque handle to the
 * function object, followed by its expected arguments:
 *
 *   step = proc do |func, *args|
 *     ...
 *   end
 *
 * The +finalize+ parameter specifies a proc object that will be invoked after
 * all rows have been processed. This gives the function an opportunity to
 * aggregate and finalize the results. It should accept a single parameter:
 * the opaque function handle:
 *
 *   finalize = proc do |func|
 *     ...
 *   end
 *
 * The function object is used when calling the #set_result, 
 * #set_result_error, #aggregate_context, and #aggregate_count methods.
 */
static VALUE
static_api_create_aggregate( VALUE module, VALUE db, VALUE name, VALUE n,
  VALUE step, VALUE finalize )
{
  sqlite *handle;
  int     result;
  VALUE   data;

  GetDB( handle, db );
  Check_Type( name, T_STRING );
  Check_Type( n, T_FIXNUM );
  if( !rb_obj_is_kind_of( step, rb_cProc ) )
  {
    rb_raise( rb_eArgError, "step must be a proc" );
  }
  if( !rb_obj_is_kind_of( finalize, rb_cProc ) )
  {
    rb_raise( rb_eArgError, "finalize must be a proc" );
  }

  /* FIXME: will the GC kill this before it is used? */
  data = rb_ary_new3( 2, step, finalize );

  result = sqlite_create_aggregate( handle,
              StringValueCStr(name),
              FIX2INT(n),
              static_function_callback,
              static_aggregate_finalize_callback,
              (void*)data );

  if( result != SQLITE_OK )
  {
    static_raise_db_error( result, "create aggregate %s(%d)",
      StringValueCStr(name), FIX2INT(n) );
    /* "raise" does not return */
  }

  return Qnil;
}

/**
 * call-seq:
 *     function_type( db, name, type ) -> nil
 *
 * Allows you to specify the type of the data that the named function returns. If
 * type is SQLite::API::NUMERIC, then the function is expected to return a numeric
 * value. If it is SQLite::API::TEXT, then the function is expected to return a
 * textual value. If it is SQLite::API::ARGS, then the function returns whatever its
 * arguments are. And if it is a positive (or zero) integer, then the function
 * returns whatever type the argument at that position is.
 */
static VALUE
static_api_function_type( VALUE module, VALUE db, VALUE name, VALUE type )
{
  sqlite *handle;
  int     result;

  GetDB( handle, db );
  Check_Type( name, T_STRING );
  Check_Type( type, T_FIXNUM );

  result = sqlite_function_type( handle,
             StringValuePtr( name ),
             FIX2INT( type ) );

  if( result != SQLITE_OK )
  {
    static_raise_db_error( result, "function type %s(%d)",
      StringValuePtr(name), FIX2INT(type) );
    /* "raise" does not return */
  }

  return Qnil;
}

/**
 * call-seq:
 *     set_result( func, result ) -> result
 *
 * Sets the result of the given function to the given value. This is typically
 * called in the callback function for #create_function or the finalize
 * callback in #create_aggregate. The result must be either a string, an integer,
 * or a double.
 *
 * The +func+ parameter must be the opaque function handle as given to the
 * callback functions mentioned above.
 */
static VALUE
static_api_set_result( VALUE module, VALUE func, VALUE result )
{
  sqlite_func *func_ptr;

  GetFunc( func_ptr, func );
  switch( TYPE(result) )
  {
    case T_STRING:
      sqlite_set_result_string( func_ptr,
        RSTRING(result)->ptr,
        RSTRING(result)->len );
      break;

    case T_FIXNUM:
      sqlite_set_result_int( func_ptr, FIX2INT(result) );
      break;

    case T_FLOAT:
      sqlite_set_result_double( func_ptr, NUM2DBL(result) );
      break;

    default:
      static_raise_db_error( -1, "bad type in set result (%d)",
        TYPE(result) );
  }

  return result;
}

/**
 * call-seq:
 *     set_result_error( func, string ) -> string
 *
 * Sets the result of the given function to be the error message given in the
 * +string+ parameter. The +func+ parameter must be an opaque function handle
 * as given to the callback function for #create_function or
 * #create_aggregate.
 */
static VALUE
static_api_set_result_error( VALUE module, VALUE func, VALUE string )
{
  sqlite_func *func_ptr;

  GetFunc( func_ptr, func );
  Check_Type( string, T_STRING );

  sqlite_set_result_error( func_ptr, RSTRING(string)->ptr,
    RSTRING(string)->len );

  return string;
}

/**
 * call-seq:
 *     aggregate_context( func ) -> hash
 *
 * Returns the aggregate context for the given function. This context is a
 * Hash object that is allocated on demand and is available only to the
 * current invocation of the function. It may be used by aggregate functions
 * to accumulate data over multiple rows, prior to being finalized.
 *
 * The +func+ parameter must be an opaque function handle as given to the
 * callbacks for #create_aggregate.
 *
 * See #create_aggregate and #aggregate_count.
 */
static VALUE
static_api_aggregate_context( VALUE module, VALUE func )
{
  sqlite_func *func_ptr;
  VALUE *ptr;

  GetFunc( func_ptr, func );

  /* FIXME: pointers to VALUEs...how nice is the GC about this kind of
   * thing? Especially when someone else frees the memory? */

  ptr = (VALUE*)sqlite_aggregate_context( func_ptr, sizeof(VALUE) );

  if( *ptr == 0 )
    *ptr = rb_hash_new();

  return *ptr;
}

/**
 * call-seq:
 *     aggregate_count( func ) -> fixnum
 *
 * Returns the number of rows that have been processed so far by the current
 * aggregate function. This always includes the current row, so that number
 * that is returned will always be at least 1.
 *
 * The +func+ parameter must be an opaque function handle as given to the
 * callbacks for #create_aggregate.
 */
static VALUE
static_api_aggregate_count( VALUE module, VALUE func )
{
  sqlite_func *func_ptr;

  GetFunc( func_ptr, func );
  return INT2FIX( sqlite_aggregate_count( func_ptr ) );
}

/*>=-----------------------------------------------------------------------=<*
 * PRIVATE FUNCTION IMPLEMENTATIONS
 * ------------------------------------------------------------------------
 * Here are the implementations of the functions declared previously.
 *>=-----------------------------------------------------------------------=<*/
NO_RDOC

/*
 * Document-class: SQLite::Exceptions
 *
 * This module contains all exceptions thrown by SQLite routines.
 */

/*
 * Document-class: SQLite::Exceptions::DatabaseException
 *
 * This is the root of the SQLite exception hierarchy. This exception will
 * be thrown for any general errors, or for exceptions for which SQLite itself
 * did not declare a specific error code.
 */

/*
 * Document-class: SQLite::Exceptions::SQLException
 *
 * From the SQLite documentation:
 *
 * "This return value indicates that there was an error in the SQL that was
 * passed into the sqlite_exec."
 */

/*
 * Document-class: SQLite::Exceptions::InternalException
 *
 * From the SQLite documentation:
 *
 * "This value indicates that an internal consistency check within the SQLite
 * library failed. This can only happen if there is a bug in the SQLite library.
 * If you ever get an SQLITE_INTERNAL reply from an sqlite_exec call, please
 * report the problem on the SQLite mailing list."
 */

/*
 * Document-class: SQLite::Exceptions::PermissionsException
 *
 * From the SQLite documentation:
 *
 * "This return value says that the access permissions on the database file are
 * such that the file cannot be opened."
 */

/*
 * Document-class: SQLite::Exceptions::AbortException
 *
 * From the SQLite documentation:
 *
 * "This value is returned if the callback function returns non-zero."
 */

/*
 * Document-class: SQLite::Exceptions::BusyException
 *
 * From the SQLite documentation:
 *
 * "This return code indicates that another program or thread has the database
 * locked. SQLite allows two or more threads to read the database at the same
 * time, but only one thread can have the database open for writing at the same
 * time. Locking in SQLite is on the entire database."
 */

/*
 * Document-class: SQLite::Exceptions::LockedException
 *
 * From the SQLite documentation:
 *
 * "This return code is similar to SQLITE_BUSY in that it indicates that the
 * database is locked. But the source of the lock is a recursive call to
 * sqlite_exec. This return can only occur if you attempt to invoke sqlite_exec
 * from within a callback routine of a query from a prior invocation of
 * sqlite_exec. Recursive calls to sqlite_exec are allowed as long as they do
 * not attempt to write the same table."
 */

/*
 * Document-class: SQLite::Exceptions::OutOfMemoryException
 *
 * From the SQLite documentation:
 *
 * "This value is returned if a call to malloc fails."
 */

/*
 * Document-class: SQLite::Exceptions::ReadOnlyException
 *
 * From the SQLite documentation:
 *
 * "This return code indicates that an attempt was made to write to a database
 * file that is opened for reading only."
 */

/*
 * Document-class: SQLite::Exceptions::InterruptException
 *
 * From the SQLite documentation:
 *
 * "This value is returned if a call to sqlite_interrupt interrupts a database
 * operation in progress."
 */

/*
 * Document-class: SQLite::Exceptions::IOErrorException
 *
 * From the SQLite documentation:
 *
 * "This value is returned if the operating system informs SQLite that it is
 * unable to perform some disk I/O operation. This could mean that there is no
 * more space left on the disk."
 */

/*
 * Document-class: SQLite::Exceptions::CorruptException
 *
 * From the SQLite documentation:
 *
 * "This value is returned if SQLite detects that the database it is working on
 * has become corrupted. Corruption might occur due to a rogue process writing
 * to the database file or it might happen due to an perviously (sic) undetected
 * logic error in of SQLite. This value is also returned if a disk I/O error
 * occurs in such a way that SQLite is forced to leave the database file in a
 * corrupted state. The latter should only happen due to a hardware or operating
 * system malfunction."
 */

/*
 * Document-class: SQLite::Exceptions::NotFoundException
 *
 * From the SQLite documentation:
 *
 * "(Internal Only) Table or record not found."
 */

/*
 * Document-class: SQLite::Exceptions::FullException
 *
 * From the SQLite documentation:
 *
 * "This value is returned if an insertion failed because there is no space
 * left on the disk, or the database is too big to hold any more information.
 * The latter case should only occur for databases that are larger than 2GB in
 * size."
 */

/*
 * Document-class: SQLite::Exceptions::CantOpenException
 *
 * From the SQLite documentation:
 *
 * "This value is returned if the database file could not be opened for some
 * reason."
 */

/*
 * Document-class: SQLite::Exceptions::ProtocolException
 *
 * From the SQLite documentation:
 *
 * "This value is returned if some other process is messing with file locks and
 * has violated the file locking protocol that SQLite uses on its rollback
 * journal files."
 */

/*
 * Document-class: SQLite::Exceptions::EmptyException
 *
 * From the SQLite documentation:
 *
 * "(Internal Only) Database table is empty"
 */

/*
 * Document-class: SQLite::Exceptions::SchemaChangedException
 *
 * From the SQLite documentation:
 *
 * "When the database first opened, SQLite reads the database schema into
 * memory and uses that schema to parse new SQL statements. If another process
 * changes the schema, the command currently being processed will abort because
 * the virtual machine code generated assumed the old schema. This is the
 * return code for such cases. Retrying the command usually will clear the
 * problem."
 */

/*
 * Document-class: SQLite::Exceptions::TooBigException
 *
 * From the SQLite documentation:
 *
 * "SQLite will not store more than about 1 megabyte of data in a single row of
 * a single table. If you attempt to store more than 1 megabyte in a single
 * row, this is the return code you get."
 */

/*
 * Document-class: SQLite::Exceptions::ConstraintException
 *
 * From the SQLite documentation:
 *
 * "This constant is returned if the SQL statement would have violated a
 * database constraint."
 */

/*
 * Document-class: SQLite::Exceptions::MismatchException
 *
 * From the SQLite documentation:
 *
 * "This error occurs when there is an attempt to insert non-integer data into
 * a column labeled INTEGER PRIMARY KEY. For most columns, SQLite ignores the
 * data type and allows any kind of data to be stored. But an INTEGER PRIMARY
 * KEY column is only allowed to store integer data."
 */

/*
 * Document-class: SQLite::Exceptions::MisuseException
 *
 * From the SQLite documentation:
 *
 * "This error might occur if one or more of the SQLite API routines is used
 * incorrectly. Examples of incorrect usage include calling sqlite_exec after
 * the database has been closed using sqlite_close or calling sqlite_exec with
 * the same database pointer simultaneously from two separate threads."
 */

/*
 * Document-class: SQLite::Exceptions::UnsupportedOSFeatureException
 *
 * From the SQLite documentation:
 *
 * "This error means that you have attempts to create or access a file
 * database file that is larger that 2GB on a legacy Unix machine that
 * lacks large file support."
 */

/*
 * Document-class: SQLite::Exceptions::AuthorizationException
 *
 * From the SQLite documentation:
 *
 * "This error indicates that the authorizer callback has disallowed the SQL
 * you are attempting to execute."
 */

/*
 * Document-class: SQLite::Exceptions::FormatException
 *
 * From the SQLite documentation:
 *
 * "Auxiliary database format error"
 */

/*
 * Document-class: SQLite::Exceptions::RangeException
 *
 * From the SQLite documentation:
 *
 * "2nd parameter to sqlite_bind out of range"
 */

/*
 * Document-class: SQLite::Exceptions::NotADatabaseException
 *
 * From the SQLite documentation:
 *
 * "File opened that is not a database file"
 */

static void
static_configure_exception_classes()
{
  int i;

  for( i = 1; g_sqlite_exceptions[ i ].name != NULL; i++ )
  {
    char name[ 128 ];

    sprintf( name, "%sException", g_sqlite_exceptions[ i ].name );
    g_sqlite_exceptions[ i ].object = rb_define_class_under( mExceptions, name, DatabaseException );
  }
}

static void
static_raise_db_error( int code, char *msg, ... )
{
  va_list args;
  char message[ 2048 ];
  VALUE exc;

  va_start( args, msg );
  vsnprintf( message, sizeof( message ), msg, args );
  va_end( args );

  exc = ( code <= 0 ? DatabaseException : g_sqlite_exceptions[ code ].object );

  rb_raise( exc, message );
}

static void
static_raise_db_error2( int code, char **msg )
{
  VALUE err = rb_str_new2( *msg ? *msg : "(no message)" );
  if( *msg ) free( *msg );
  *msg = NULL;

  static_raise_db_error( code, "%s", STR2CSTR( err ) );
}

static void
static_free_vm( sqlite_vm *vm )
{
  /* FIXME: can sqlite_finalize be called with a second parameter of NULL? */
  sqlite_finalize( vm, NULL );
}

static int
static_busy_handler( void* cookie, const char *entity, int times )
{
  VALUE handler = (VALUE)cookie;
  VALUE result;

  result = rb_funcall( handler, idCall, 2, rb_str_new2( entity ),
    INT2FIX( times ) );

  if( result == Qnil || result == Qfalse )
    return 0;

  return 1;
}

static VALUE
static_protected_function_callback( VALUE args )
{
  VALUE proc;
  VALUE proc_args;

  proc = rb_ary_entry( args, 0 );
  proc_args = rb_ary_entry( args, 1 );

  rb_apply( proc, idCall, proc_args );
  
  return Qnil;
}

static void
static_function_callback( sqlite_func *func, int argc, const char **argv )
{
  VALUE proc;
  VALUE args;
  VALUE protect_args;
  int   index;
  int   exception = 0;

  proc = (VALUE)sqlite_user_data( func );
  if( TYPE(proc) == T_ARRAY )
    proc = rb_ary_entry( proc, 0 );

  args = rb_ary_new2( argc + 1 );
  rb_ary_push( args, Data_Wrap_Struct( rb_cData, NULL, NULL, func ) );

  for( index = 0; index < argc; index++ )
  {
    VALUE entry = Qnil;

    if( argv[index] )
      entry = rb_str_new2( argv[index] );

    rb_ary_push( args, entry );
  }

  protect_args = rb_ary_new3( 2, proc, args );
  rb_protect( static_protected_function_callback,
              protect_args,
              &exception );

  if( exception )
  {
    sqlite_set_result_error( func, "error occurred while processing function", -1 );
  }
}

static void
static_aggregate_finalize_callback( sqlite_func *func )
{
  VALUE  proc;
  VALUE  args;
  VALUE  protect_args;
  int    exception = 0;

  proc = rb_ary_entry( (VALUE)sqlite_user_data( func ), 1 );
  args = rb_ary_new3( 1, Data_Wrap_Struct( rb_cData, NULL, NULL, func ) );

  protect_args = rb_ary_new3( 2, proc, args );

  rb_protect( static_protected_function_callback,
              protect_args,
              &exception );

  if( exception )
  {
    sqlite_set_result_error( func, "error occurred while processing aggregate finalize", -1 );
  }
}

/*>=-----------------------------------------------------------------------=<*
 * MODULE INITIALIZATION
 * ------------------------------------------------------------------------
 * This is the "main" function for a Ruby extension. When Ruby loads the
 * extension, it will invoke this method to set things up. For this
 * extension, it defines the SQLite and SQLite::API modules, and then
 * declares the API method hooks.
 *>=-----------------------------------------------------------------------=<*/
NO_RDOC

/**
 * Document-class: SQLite::API
 *
 * This is a one-to-one bridge between Ruby code and the C interface for SQLite.
 * It defines (more-or-less) one method per function (with #set_result being
 * one exception). It is generally not advisable to use these methods directly;
 * instead, you should use the SQLite::Database class and related interfaces,
 * which provide a more object-oriented view of this interface.
 */
void Init_sqlite_api()
{
  idRow = rb_intern( "row" );
  idColumns = rb_intern( "columns" );
  idTypes = rb_intern( "types" );
  idCall = rb_intern( "call" );

  mSQLite = rb_define_module( "SQLite" );
  mExceptions = rb_define_module_under( mSQLite, "Exceptions" );

  DatabaseException = rb_define_class_under( mExceptions, "DatabaseException",
    rb_eStandardError );

  static_configure_exception_classes();

  mAPI = rb_define_module_under( mSQLite, "API" );

  rb_define_const( mAPI, "VERSION", rb_str_new2( sqlite_libversion() ) );
  rb_define_const( mAPI, "ENCODING", rb_str_new2( sqlite_libencoding() ) );
  rb_define_const( mAPI, "NUMERIC", INT2FIX( SQLITE_NUMERIC ) );
  rb_define_const( mAPI, "TEXT", INT2FIX( SQLITE_TEXT ) );
  rb_define_const( mAPI, "ARGS", INT2FIX( SQLITE_ARGS ) );

  rb_define_module_function( mAPI, "open", static_api_open, 2 );
  rb_define_module_function( mAPI, "close", static_api_close, 1 );

  rb_define_module_function( mAPI, "compile", static_api_compile, 2 );
  rb_define_module_function( mAPI, "step", static_api_step, 1 );
  rb_define_module_function( mAPI, "finalize", static_api_finalize, 1 );

  rb_define_module_function( mAPI, "last_insert_row_id",
    static_api_last_insert_row_id, 1 );
  rb_define_module_function( mAPI, "changes", static_api_changes, 1 );

  rb_define_module_function( mAPI, "interrupt", static_api_interrupt, 1 );

  rb_define_module_function( mAPI, "complete", static_api_complete, 1 );

  rb_define_module_function( mAPI, "busy_handler", static_api_busy_handler, 2 );
  rb_define_module_function( mAPI, "busy_timeout", static_api_busy_timeout, 2 );

  rb_define_module_function( mAPI, "create_function",
    static_api_create_function, 4 );
  rb_define_module_function( mAPI, "create_aggregate",
    static_api_create_aggregate, 5 );
  rb_define_module_function( mAPI, "function_type",
    static_api_function_type, 3 );

  rb_define_module_function( mAPI, "set_result",
    static_api_set_result, 2 );
  rb_define_module_function( mAPI, "set_result_error",
    static_api_set_result_error, 2 );

  rb_define_module_function( mAPI, "aggregate_context",
    static_api_aggregate_context, 1 );
  rb_define_module_function( mAPI, "aggregate_count",
    static_api_aggregate_count, 1 );
}
