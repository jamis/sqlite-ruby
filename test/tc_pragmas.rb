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

class TC_Pragmas < Test::Unit::TestCase

  def setup
    @db = SQLite::Database.open( "db/fixtures.db" )
  end

  def teardown
    @db.close
  end

  def test_integrity_check
    assert_nothing_raised do
      @db.integrity_check
    end
  end

  def test_cache_size
    size = @db.cache_size
    assert_instance_of Fixnum, size
    @db.cache_size = size + 100
    new_size = @db.cache_size
    assert_equal size+100, new_size
  end

  def test_default_cache_size
    size = @db.default_cache_size
    assert_instance_of Fixnum, size
    @db.default_cache_size = size + 100
    new_size = @db.default_cache_size
    assert_equal size+100, new_size
  end

  def test_synchronous
    assert_raise( SQLite::Exceptions::DatabaseException ) do
      @db.synchronous = "bogus"
    end

    assert_nothing_raised do
      @db.synchronous = "full"
      @db.synchronous = 2
      @db.synchronous = "normal"
      @db.synchronous = 1
      @db.synchronous = "off"
      @db.synchronous = 0
    end

    assert_equal "0", @db.synchronous
  end

  def test_default_synchronous
    assert_raise( SQLite::Exceptions::DatabaseException ) do
      @db.default_synchronous = "bogus"
    end

    assert_nothing_raised do
      @db.default_synchronous = "full"
      @db.default_synchronous = 2
      @db.default_synchronous = "normal"
      @db.default_synchronous = 1
      @db.default_synchronous = "off"
      @db.default_synchronous = 0
    end

    assert_equal "0", @db.default_synchronous
  end

  def test_temp_store
    assert_raise( SQLite::Exceptions::DatabaseException ) do
      @db.temp_store = "bogus"
    end

    assert_nothing_raised do
      @db.temp_store = "memory"
      @db.temp_store = 2
      @db.temp_store = "file"
      @db.temp_store = 1
      @db.temp_store = "default"
      @db.temp_store = 0
    end

    assert_equal "0", @db.temp_store
  end

  def test_default_temp_store
    assert_raise( SQLite::Exceptions::DatabaseException ) do
      @db.default_temp_store = "bogus"
    end

    assert_nothing_raised do
      @db.default_temp_store = "memory"
      @db.default_temp_store = 2
      @db.default_temp_store = "file"
      @db.default_temp_store = 1
      @db.default_temp_store = "default"
      @db.default_temp_store = 0
    end

    assert_equal "0", @db.default_temp_store
  end

  def test_full_column_names
    assert_raise( SQLite::Exceptions::DatabaseException ) do
      @db.full_column_names = "sure"
    end

    assert_raise( SQLite::Exceptions::DatabaseException ) do
      @db.full_column_names = :yes
    end

    assert_nothing_raised do
      @db.full_column_names = "yes"
      @db.full_column_names = "no"
      @db.full_column_names = 1
      @db.full_column_names = 0
      @db.full_column_names = true
      @db.full_column_names = false
      @db.full_column_names = nil
      @db.full_column_names = "y"
      @db.full_column_names = "n"
      @db.full_column_names = "t"
      @db.full_column_names = "f"
    end

    assert !@db.full_column_names
  end

  def test_parser_trace
    # apparently, the parser_trace pragma always returns true...?
    assert @db.parser_trace
    #@db.parser_trace = false
    #assert !@db.parser_trace
  end

  def test_vdbe_trace
    @db.vdbe_trace = true
    assert @db.vdbe_trace
    @db.vdbe_trace = false
    assert !@db.vdbe_trace
  end

  def test_database_list
    assert_equal ["main","temp"], @db.database_list.map { |i| i[1] }
  end

  def test_foreign_key_list
    list = @db.foreign_key_list( "D" )
    assert_equal 1, list.size
    assert_equal "B", list.first[2]
  end

  def test_index_info
    info = @db.index_info( "B_idx" )
    assert_equal 1, info.size
    assert_equal "name", info.first[2]
  end

  def test_index_list
    list = @db.index_list( "B" )
    assert_equal 1, list.size
    assert_equal "B_idx", list.first[1]
  end

  def test_table_info
    info = @db.table_info( "A" )
    assert_equal 2, info.size
    assert_equal "name", info[0][1]
    assert_equal "age", info[1][1]
  end

end
