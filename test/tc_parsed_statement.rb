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

require 'sqlite/parsed_statement'
require 'test/unit'

class TC_ParsedStatement < Test::Unit::TestCase

  def test_trailing
    sql = %q{first; and second}
    stmt = SQLite::ParsedStatement.new( sql )
    assert_equal "first", stmt.sql
    assert_equal " and second", stmt.trailing

    sql = %q{first}
    stmt = SQLite::ParsedStatement.new( sql )
    assert_equal "first", stmt.sql
    assert_equal "", stmt.trailing
  end

  def test_text_only_statement
    sql = %q{select * from some.table t where ( t.b = 'a string' )}

    stmt = SQLite::ParsedStatement.new( sql )
    expected = "select * from some.table t where ( t.b = 'a string' )"

    assert_equal expected, stmt.sql
    assert_equal expected, stmt.to_s
    assert_equal expected, stmt.to_str

    stmt.bind_params
    assert_equal expected, stmt.to_s
  end

  def test_bind_single_positional_param
    sql = %q{select * from some.table t where ( t.b = ? )}

    expected = "select * from some.table t where ( t.b = NULL )"
    stmt = SQLite::ParsedStatement.new( sql )
    assert_equal expected, stmt.to_s

    expected = "select * from some.table t where ( t.b = 'a string' )"

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_params( "a string" )
    assert_equal expected, stmt.to_s

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_param( 1, "a string" )
    assert_equal expected, stmt.to_s
  end

  def test_bind_multiple_positional_params
    sql = %q{? and ? and ?}
    expected = "'one' and NULL and 'O''Reilly'"

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_param( 1, "one" )
    stmt.bind_param( 3, "O'Reilly" )
    stmt.bind_param( 4, "ignored" )
    assert_equal expected, stmt.to_s

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_params( "one", nil, "O'Reilly", "ignored" )
    assert_equal expected, stmt.to_s
  end

  def test_syntax_bind_positional_params
    sql = %q{? and ? and ?1}
    expected = "'one' and NULL and 'one'"

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_param( 1, "one" )
    stmt.bind_param( 3, "O'Reilly" )
    stmt.bind_param( 4, "ignored" )
    assert_equal expected, stmt.to_s

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_params( "one", nil, "O'Reilly", "ignored" )
    assert_equal expected, stmt.to_s

    sql = %q{:2 and ? and ?1 and :4:}
    expected = "NULL and 'O''Reilly' and 'one' and 'ignored'"
    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_params( "one", nil, "O'Reilly", "ignored" )
    assert_equal expected, stmt.to_s
  end

  def test_bind_named_params
    sql = %q{:name and :spouse:}
    expected = "'joe' and NULL"

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_param( "name", "joe" )
    assert_equal expected, stmt.to_s

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_params( "name"=>"joe", "spouse"=>nil )
    assert_equal expected, stmt.to_s

    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_params( "name"=>"joe", "spouse"=>"jane" )
    assert_equal "'joe' and 'jane'", stmt.to_s
  end

  def test_mixed_params
    sql = %q{:name and :spouse: and ?2 and ? and :1 and :2:}
    stmt = SQLite::ParsedStatement.new( sql )
    stmt.bind_params( "one", 2, "three",
          "name"=>"joe", "spouse"=>"jane" )

    assert_equal "'joe' and 'jane' and 2 and 'three' and 'one' and 2", stmt.to_s
  end

  def test_sql
    sql = %q{:name and :spouse: and ?2 and ? and :1 and :2:}
    stmt = SQLite::ParsedStatement.new( sql )
    assert_equal ":name and :spouse and :2 and :3 and :1 and :2", stmt.sql
  end

  def test_placeholders
    sql = %q{:name and :spouse: and ? and ?5 and :12 and :15:}

    stmt = SQLite::ParsedStatement.new( sql )
    assert_equal 6, stmt.placeholders.length
    assert( ( [ "name", "spouse", 1, 5, 12, 15 ] - stmt.placeholders ).empty? )
  end

  def test_begin_end
    sql = %Q{begin\n  delete blah;\n  and blah;\nend; extra}
    stmt = SQLite::ParsedStatement.new( sql )
    assert_equal "begin delete blah; and blah; end", stmt.sql
    assert_equal " extra", stmt.trailing
  end

  def test_begin
    sql = %Q{begin ; end}
    stmt = SQLite::ParsedStatement.new( sql )
    assert_equal "begin", stmt.sql
    assert_equal " end", stmt.trailing
  end

  def test_begin_transaction
    sql = %Q{begin transaction; blah}
    stmt = SQLite::ParsedStatement.new( sql )
    assert_equal "begin transaction", stmt.sql
    assert_equal " blah", stmt.trailing
  end

end
