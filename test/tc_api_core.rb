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

$:.unshift "lib"

require 'sqlite_api'
require 'test/unit'

# MISSING TESTS FOR:
#   SQLite::Exceptions::BusyException (and related cases)
#   API.interrupt
#   API.busy_handler
#   API.busy_timeout
#   API.function_type
#   API.set_result_error

class TC_APICore < Test::Unit::TestCase
  include SQLite

  def test_constants
    assert_equal( "constant", defined? API::VERSION )
    assert_equal( "constant", defined? API::ENCODING )
    assert_equal( "constant", defined? API::NUMERIC )
    assert_equal( "constant", defined? API::TEXT )
    assert_equal( "constant", defined? API::ARGS )
  end

  def test_open_new
    assert !File.exist?( "db/dummy.db" )
    db = API.open( "db/dummy.db", 0 )
    assert File.exist?( "db/dummy.db" )
    API.close db
    File.delete "db/dummy.db"
  end

  def test_compile
    db = API.open( "db/fixtures.db", 0 )
    vm, rest = API.compile( db, "select name, age from A order by name;extra" )
    assert_equal "extra", rest
    result = API.step( vm )
    assert_nil result[:row][0]
    assert_equal ["name","age"], result[:columns]
    result = API.step( vm )
    assert_equal 'Amber', result[:row][0]
    result = API.step( vm )
    assert_equal 'Cinnamon', result[:row][0]
    result = API.step( vm )
    assert_equal 'Juniper', result[:row][0]
    result = API.step( vm )
    assert_equal 'Timothy', result[:row][0]
    result = API.step( vm )
    assert_equal 'Zephyr', result[:row][0]
    result = API.step( vm )
    assert !result.has_key?(:row)

    assert_raise( SQLite::Exceptions::MisuseException ) do
      API.step( vm )
    end

    API.finalize( vm )
    API.close( db )
  end

  def test_bad_compile
    db = API.open( "db/fixtures.db", 0 )
    assert_raise( SQLite::Exceptions::SQLException ) do
      API.compile( db, "select name, age from BOGUS order by name" )
    end
    API.close( db )
  end

  def test_empty_compile
    db = API.open( "db/fixtures.db", 0 )
    vm, rest = API.compile( db, "select * from B order by name" )
    result = API.step( vm )
    assert !result.has_key?(:row)
    assert_equal ["id","name"], result[:columns]
    API.finalize( vm )
    API.close( db )
  end

  def test_last_insert_row_id
    db = API.open( "db/dummy.db", 0 )

    vm, rest = API.compile( db, "create table Z ( a integer primary key, b varchar(60) )" )
    API.step(vm)
    API.finalize(vm)

    vm, rest = API.compile( db, "insert into Z values ( 14, 'Hello' )" )
    API.step(vm)
    API.finalize(vm)

    assert_equal 14, API.last_insert_row_id( db )

    API.close(db)

  ensure
    File.delete( "db/dummy.db" )
  end

  def test_changes
    db = API.open( "db/dummy.db", 0 )

    vm, rest = API.compile( db, "create table Z ( a integer primary key, b varchar(60) )" )
    API.step(vm)
    API.finalize(vm)

    vm, rest = API.compile( db, "insert into Z values ( 14, 'Hello' )" )
    API.step(vm)
    API.finalize(vm)

    assert_equal 1, API.changes( db )

    vm, rest = API.compile( db, "insert into Z values ( 15, 'Hello' )" )
    API.step(vm)
    API.finalize(vm)

    vm, rest = API.compile( db, "delete from Z where 1" )
    API.step(vm)
    API.finalize(vm)

    assert_equal 2, API.changes( db )

    API.close(db)

  ensure
    File.delete( "db/dummy.db" )
  end

  def test_complete
    sql = "select * from"
    assert !API.complete( sql )
    sql << "a_table;"
    assert API.complete( sql )
  end

  def test_create_function
    db = API.open( "db/fixtures.db", 0 )

    API.create_function( db, "maim", 1, proc { |func,arg| API.set_result( func, arg.split(//).sort.join ) } )

    vm, rest = API.compile( db, "select maim(name) from A where name = 'Amber'" )
    result = API.step( vm )
    assert_equal "Abemr", result[:row][0]
    API.finalize( vm )

    API.close( db )
  end

  def test_create_aggregate
    db = API.open( "db/fixtures.db", 0 )

    API.create_aggregate( db, "lengths", 1,
      proc { |func,arg|
        ctx = API.aggregate_context( func )
        ctx[:count] = API.aggregate_count( func )
        ctx[:len] ||= 0
        ctx[:len] += ( arg.nil? ? 0 : arg.length )
      },
      proc { |func|
        ctx = API.aggregate_context( func )
        API.set_result( func, "#{ctx[:len] || 0}/#{ctx[:count] || 0}" )
      } )

    vm, rest = API.compile( db, "select lengths(name) from A" )
    result = API.step( vm )
    assert_equal "33/6", result[:row][0]
    API.finalize( vm )

    API.close( db )
  end
end
