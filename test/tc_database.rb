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

require 'sqlite'
require 'test/unit'

class TC_Database < Test::Unit::TestCase

  def setup
    @db = SQLite::Database.open( "db/fixtures.db" )
  end

  def teardown
    @db.close
  end

  def test_constants
    assert_equal "constant", defined?( SQLite::Version::MAJOR )
    assert_equal "constant", defined?( SQLite::Version::MINOR )
    assert_equal "constant", defined?( SQLite::Version::TINY )
    assert_equal "constant", defined?( SQLite::Version::STRING )

    expected = [ SQLite::Version::MAJOR, SQLite::Version::MINOR,
      SQLite::Version::TINY ].join( "." )

    assert_equal expected, SQLite::Version::STRING
  end

  def test_execute_no_block
    rows = @db.execute( "select * from A order by name limit 2" )

    assert_equal [ [nil, "6"], ["Amber", "5"] ], rows
  end

  def test_execute_with_block
    expect = [ [nil, "6"], ["Amber", "5"] ]
    @db.execute( "select * from A order by name limit 2" ) do |row|
      assert_equal expect.shift, row
    end
    assert expect.empty?
  end

  def test_execute2_no_block
    columns, *rows = @db.execute2( "select * from A order by name limit 2" )

    assert_equal [ "name", "age" ], columns
    assert_equal [ [nil, "6"], ["Amber", "5"] ], rows
  end

  def test_execute2_with_block
    expect = [ ["name", "age"], [nil, "6"], ["Amber", "5"] ]
    @db.execute2( "select * from A order by name limit 2" ) do |row|
      assert_equal expect.shift, row
    end
    assert expect.empty?
  end

  def test_bind_vars
    rows = @db.execute( "select * from A where name = ?", "Amber" )
    assert_equal [ ["Amber", "5"] ], rows
    rows = @db.execute( "select * from A where name = ?", 15 )
    assert_equal [], rows
  end

  def test_result_hash
    @db.results_as_hash = true
    rows = @db.execute( "select * from A where name = ?", "Amber" )
    assert_equal [ {"name"=>"Amber", 0=>"Amber", "age"=>"5", 1=>"5"} ], rows
  end

  def test_result_hash_types
    @db.results_as_hash = true
    rows = @db.execute( "select * from A where name = ?", "Amber" )
    assert_equal [ "VARCHAR(60)", "INTEGER" ], rows[0].types
  end

  def test_query
    @db.query( "select * from A where name = ?", "Amber" ) do |result|
      row = result.next
      assert_equal [ "Amber", "5"], row
    end
  end

  def test_metadata
    @db.query( "select * from A where name = ?", "Amber" ) do |result|
      assert_equal [ "name", "age" ], result.columns
      assert_equal [ "VARCHAR(60)", "INTEGER" ], result.types
      assert_equal [ "Amber", "5"], result.next
    end
  end

  def test_get_first_row
    row = @db.get_first_row( "select * from A order by name" )
    assert_equal [ nil, "6" ], row
  end

  def test_get_first_value
    age = @db.get_first_value( "select age from A order by name" )
    assert_equal "6", age
  end

  def test_create_function
    @db.create_function( "maim", 1 ) do |func, value|
      if value.nil?
        func.set_result nil
      else
        func.set_result value.split(//).sort.join
      end
    end

    value = @db.get_first_value( "select maim(name) from A where name='Amber'" )
    assert_equal "Abemr", value
  end

  def test_create_aggregate
    step = proc do |func, value|
      func[ :total ] ||= 0
      func[ :total ] += ( value ? value.length : 0 )
    end

    finalize = proc do |func|
      func.set_result( func[ :total ] || 0 )
    end

    @db.create_aggregate( "lengths", 1, step, finalize )

    value = @db.get_first_value( "select lengths(name) from A" )
    assert_equal "33", value
  end

  def test_set_error
    @db.create_function( "barf", 1 ) do |func, value|
      func.set_error "oops! I did it again"
    end

    assert_raise( SQLite::Exceptions::SQLException ) do
      @db.get_first_value( "select barf(name) from A where name='Amber'" )
    end
  end

  def test_context_on_nonaggregate
    @db.create_function( "barf1", 1 ) do |func, value|
      assert_raise( SQLite::Exceptions::MisuseException ) do
        func['hello']
      end
    end

    @db.create_function( "barf2", 1 ) do |func, value|
      assert_raise( SQLite::Exceptions::MisuseException ) do
        func['hello'] = "world"
      end
    end

    @db.create_function( "barf3", 1 ) do |func, value|
      assert_raise( SQLite::Exceptions::MisuseException ) do
        func.count
      end
    end

    @db.get_first_value( "select barf1(name) from A where name='Amber'" )
    @db.get_first_value( "select barf2(name) from A where name='Amber'" )
    @db.get_first_value( "select barf3(name) from A where name='Amber'" )
  end

  class LengthsAggregate
    def self.function_type
      :numeric
    end

    def self.arity
      1
    end

    def self.name
      "lengths"
    end

    def initialize
      @total = 0
    end

    def step( ctx, name )
      @total += ( name ? name.length : 0 )
    end

    def finalize( ctx )
      ctx.set_result( @total )
    end
  end

  def test_create_aggregate_handler
    @db.create_aggregate_handler LengthsAggregate

    result = @db.get_first_value( "select lengths(name) from A" )
    assert_equal "33", result
  end

  def test_prepare
    stmt = @db.prepare( "select * from A" )
    assert_equal "", stmt.remainder
    assert_equal [ "name", "age" ], stmt.columns
    assert_equal [ "VARCHAR(60)", "INTEGER" ], stmt.types
    stmt.execute do |result|
      row = result.next
      assert_equal [ "Zephyr", "1" ], row
    end
  end

  def test_prepare_bind_execute
    stmt = @db.prepare( "select * from A where age = ?" )
    stmt.bind_params 1
    stmt.execute do |result|
      row = result.next
      assert_equal [ "Zephyr", "1" ], row
      assert_nil result.next
    end
  end

  def test_prepare_bind_execute!
    stmt = @db.prepare( "select * from A where age = ?" )
    stmt.bind_params 1
    rows = stmt.execute!
    assert_equal 1, rows.length
    assert_equal [ "Zephyr", "1" ], rows.first
  end

  def test_prepare_execute
    stmt = @db.prepare( "select * from A where age = ?" )
    stmt.execute( 1 ) do |result|
      row = result.next
      assert_equal [ "Zephyr", "1" ], row
      assert_nil result.next
    end
  end

  def test_prepare_execute!
    stmt = @db.prepare( "select * from A where age = ?" )
    rows = stmt.execute!( 1 )
    assert_equal 1, rows.length
    assert_equal [ "Zephyr", "1" ], rows.first
  end

  def test_execute_batch
    count = @db.get_first_value( "select count(*) from A" ).to_i

    @db.execute_batch( %q{--- query number one
                        insert into A ( age, name ) values ( 200, 'test' );
                        /* query number
                         * two */
                        insert into A ( age, name ) values ( 201, 'test2' );
                        insert into A ( age, name ) values ( 202, /* comment here */ 'test3' )} )
    new_count = @db.get_first_value( "select count(*) from A" ).to_i
    assert_equal 3, new_count - count

    @db.execute_batch( %q{--- query number one
                        delete from A where age = 200;
                        /* query number
                         * two */
                        delete from A where age = 201;
                        delete from /* comment */ A where age = 202;} )

    new_count = @db.get_first_value( "select count(*) from A" ).to_i
    assert_equal new_count, count

    assert_nothing_raised do
      @db.execute_batch( "delete from A where age = 200;\n" )
    end
  end

  def test_transaction_block_errors
    assert_raise( SQLite::Exceptions::SQLException ) do
      @db.transaction do
        @db.commit
      end
    end

    assert_raise( SQLite::Exceptions::SQLException ) do
      @db.transaction do
        @db.rollback
      end
    end
  end

  def test_transaction_errors
    assert_raise( SQLite::Exceptions::SQLException ) do
      @db.commit
    end
    assert_raise( SQLite::Exceptions::SQLException ) do
      @db.rollback
    end
  end

  def test_transaction_block_good
    count = @db.get_first_value( "select count(*) from A" ).to_i
    begin
      @db.transaction do |db|
        assert @db.transaction_active?
        db.execute( "insert into A values ( 'bogus', 1 )" )
        sub_count = db.get_first_value( "select count(*) from A" ).to_i
        assert_equal count+1, sub_count
        raise "testing rollback..."
      end
    rescue Exception
    end
    new_count = @db.get_first_value( "select count(*) from A" ).to_i
    assert_equal count, new_count

    @db.transaction do |db|
      db.execute( "insert into A values ( 'bogus', 1 )" )
      sub_count = db.get_first_value( "select count(*) from A" ).to_i
      assert_equal count+1, sub_count
    end
    new_count = @db.get_first_value( "select count(*) from A" ).to_i
    assert_equal count+1, new_count

    @db.execute( "delete from A where name = ?", "bogus" )
  end

  def test_transaction_explicit
    count = @db.get_first_value( "select count(*) from A" ).to_i

    @db.transaction
    assert @db.transaction_active?
    @db.execute( "insert into A values ( 'bogus', 1 )" )
    sub_count = @db.get_first_value( "select count(*) from A" ).to_i
    assert_equal count+1, sub_count
    @db.rollback
    sub_count = @db.get_first_value( "select count(*) from A" ).to_i
    assert_equal count, sub_count

    @db.transaction
    @db.execute( "insert into A values ( 'bogus', 1 )" )
    sub_count = @db.get_first_value( "select count(*) from A" ).to_i
    assert_equal count+1, sub_count
    @db.commit
    sub_count = @db.get_first_value( "select count(*) from A" ).to_i
    assert_equal count+1, sub_count

    @db.execute( "delete from A where name = ?", "bogus" )
  end

end
