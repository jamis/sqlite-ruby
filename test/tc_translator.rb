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

require 'base64'
require 'sqlite/translator'
require 'test/unit'

class TC_Translator < Test::Unit::TestCase

  def setup
    @translator = SQLite::Translator.new
  end

  def test_date_time
    value = "2004-09-08 14:09:39"
    expect = Time.mktime( 2004, 9, 8, 14, 9, 39 )

    assert_equal expect, @translator.translate( "date", value )
    assert_equal expect, @translator.translate( "datetime", value )
    assert_equal expect, @translator.translate( "time", value )
  end

  def test_real
    value = "3.1415"
    expect = 3.1415

    assert_equal expect, @translator.translate( "decimal", value )
    assert_equal expect, @translator.translate( "float", value )
    assert_equal expect, @translator.translate( "numeric", value )
    assert_equal expect, @translator.translate( "double", value )
    assert_equal expect, @translator.translate( "real", value )
    assert_equal expect, @translator.translate( "dec", value )
    assert_equal expect, @translator.translate( "fixed", value )
  end

  def test_integer
    value = "128"
    expect = 128

    assert_equal expect, @translator.translate( "integer", value )
    assert_equal expect, @translator.translate( "smallint", value )
    assert_equal expect, @translator.translate( "mediumint", value )
    assert_equal expect, @translator.translate( "int", value )
    assert_equal expect, @translator.translate( "bigint", value )
  end

  def test_boolean
    assert_equal true, @translator.translate( "bit", "1" )
    assert_equal false, @translator.translate( "bit", "0" )
    assert_equal false, @translator.translate( "bool", "0" )
    assert_equal false, @translator.translate( "bool", "false" )
    assert_equal false, @translator.translate( "bool", "f" )
    assert_equal false, @translator.translate( "bool", "no" )
    assert_equal false, @translator.translate( "bool", "n" )
    assert_equal false, @translator.translate( "boolean", "0" )
    assert_equal false, @translator.translate( "boolean", "false" )
    assert_equal false, @translator.translate( "boolean", "f" )
    assert_equal false, @translator.translate( "boolean", "no" )
    assert_equal false, @translator.translate( "boolean", "n" )
    assert_equal true, @translator.translate( "bool", "heck ya!" )
    assert_equal true, @translator.translate( "boolean", "heck ya!" )
  end

  def test_timestamp
    time = Time.mktime( 2004, 9, 8, 14, 9, 39 )
    assert_equal time, @translator.translate( "timestamp", time.to_i.to_s )
  end

  def test_tinyint
    assert_equal true, @translator.translate( "tinyint(1)", "1" )
    assert_equal false, @translator.translate( "tinyint(1)", "0" )
    assert_equal 16, @translator.translate( "tinyint", "16" )
  end

  def test_custom
    @translator.add_translator( "object" ) { |t,v| Marshal.load( Base64.decode64( v ) ) }

    value = { :one => "hello", :four => "blah" }
    dump = Base64.encode64( Marshal.dump( value ) ).strip

    assert_equal value, @translator.translate( "object", dump )
  end

end
