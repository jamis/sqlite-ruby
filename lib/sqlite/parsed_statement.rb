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

require 'strscan'

module SQLite

  # A ParsedStatement instance represents a tokenized version of an SQL
  # statement. This makes it possible to do bind variable replacements multiple
  # times, fairly efficiently.
  #
  # Within the SQLite interfaces, this is used only by the Statement class.
  # However, it could be reused by other SQL-reliant classes easily.
  class ParsedStatement

    # This represents a textual token in an SQL statement. It is only used by
    # ParsedStatement.
    class Token # :nodoc:

      # Create a new Token that encapsulates the given text.
      def initialize( text )
        @text = text
      end

      # Append the given text onto the the contents of this Token.
      def <<( text )
        @text << text.to_s
      end

      # Convert this Token into a string. The +vars+ parameter is ignored.
      def to_s( vars=nil )
        @text
      end

    end

    # This represents a bind variable in a tokenized SQL stream. It is used
    # only by ParsedStatement.
    class BindVariable # :nodoc:

      # Create a new BindVariable token encapsulating the given name. The
      # name is used when looking up a bind variable to bind to the place
      # holder represented by this token. The name may be either a Fixnum
      # (in which case it represents an positional placeholder) or a
      # a String (in which case it represents a named placeholder).
      def initialize( name )
        @name = name
      end

      # Convert the token to a string. If the +vars+ parameter is +nil+, then
      # the string will be in the format <tt>?nnn</tt> (where _nnn_ is the
      # index that was used to initialize this token). Otherwise, the +vars+
      # parameter must be a hash, and the value bound to this token is the
      # element with the key given to this token when it was created. If that
      # element is +nil+, this will return the string "NULL". If the element
      # is a String, then it will be quoted and escaped and returned.
      # Otherwise, the "to_s" method of the element will be called and the
      # result returned.
      def to_s( vars=nil )
        if vars.nil?
          ":#{@name}"
        else
          var = vars[ @name ]
          case var
            when nil
              "NULL"
            when String
              "'#{var.gsub(/'/,"''")}'"
            else
              var.to_s
          end
        end
      end

    end

    # The text trailing the first recognized SQL statement that was parsed from
    # the buffer given to this object. If there was no trailing SQL statement,
    # this property will be the empty string.
    attr_reader :trailing

    # Create a new ParsedStatement. This will tokenize the given buffer. As an
    # optimization, the tokenization is only performed if the string matches
    # /[?:;]/, otherwise the string is used as-is.
    def initialize( sql )
      @bind_values = Hash.new

      if sql.index( /[?:;]/ )
        @tokens, @trailing = tokenize( sql )
      else
        @tokens, @trailing = [ Token.new(sql) ], ""
      end
    end

    # Returns an array of the placeholders known to this statement. This will
    # either be empty (if the statement has no placeholders), or will contain
    # numbers (indexes) and strings (names).
    def placeholders
      @bind_values.keys
    end

    # Returns the SQL that was given to this parsed statement when it was
    # created, with bind placeholders intact.
    def sql
      @tokens.inject( "" ) { |sql,tok| sql << tok.to_s }
    end

    # Returns the statement as an SQL string, with all placeholders bound to
    # their corresponding values.
    def to_s
      @tokens.inject( "" ) { |sql,tok| sql << tok.to_s( @bind_values ) }
    end

    alias :to_str :to_s

    # Binds the given parameters to the placeholders in the statement. It does
    # this by iterating over each argument and calling #bind_param with the
    # corresponding index (starting at 1). However, if any element is a hash,
    # the hash is iterated through and #bind_param called for each key/value
    # pair. Hash's do not increment the index.
    def bind_params( *bind_vars )
      index = 1
      bind_vars.each do |value|
        if value.is_a?( Hash )
          value.each_pair { |key, value| bind_param( key, value ) }
        else
          bind_param index, value
          index += 1
        end
      end
      self
    end

    # Binds the given value to the placeholder indicated by +param+, which may
    # be either a Fixnum or a String. If the indicated placeholder does not
    # exist in the statement, this method does nothing.
    def bind_param( param, value )
      return unless @bind_values.has_key?( param )
      @bind_values[ param ] = value
    end

    # Tokenizes the given SQL string, returning a tuple containing the array of
    # tokens (optimized so that each text token contains the longest run of
    # text possible), and any trailing text that follows the statement.
    def tokenize( sql )
      tokens = []

      scanner = StringScanner.new( sql )
      variable_index = 0
      allow_break = true

      until scanner.eos?
        tokens << " " unless tokens.empty? if scanner.scan( /\s+/ )
        break if scanner.eos?

        if scanner.scan( /;/ )
          break if allow_break
          tokens << Token.new( ";" )
        elsif scanner.scan( /\bbegin\s+transaction\b/i )
          tokens << Token.new( "begin transaction" )
        elsif scanner.scan( /\bbegin\b(?=\s*[^\s;]|$)/im )
          tokens << Token.new( "begin" )
          allow_break = false
        elsif !allow_break && scanner.scan( /\bend\b/i )
          tokens << Token.new( "end" )
          allow_break = true
        elsif scanner.scan( /---.*$/ ) || scanner.scan( %r{/\*.*?\*/}m )
          # comments
          next
        elsif scanner.scan( /[-+*\/\w=<>!(),.]+/ )
          tokens << Token.new( scanner.matched )
        elsif scanner.scan( /['"]/ )
          delim = scanner.matched
          token = delim.dup
          loop do
            token << scanner.scan_until( /#{delim}/ )
            match = scanner.matched
            break if match.length % 2 == 1
          end
          tokens << Token.new( token )
        elsif scanner.scan( /\?(\d+)?/ )
          variable_index = ( scanner[1] ? scanner[1].to_i : variable_index+1 )
          tokens << BindVariable.new( variable_index )
          @bind_values[variable_index] = nil
        elsif scanner.scan( /:(\w+):?/ )
          name = scanner[1]
          variable_index = name = name.to_i if name !~ /\D/
          tokens << BindVariable.new( name )
          @bind_values[name] = nil
        else
          raise "unknown token #{scanner.rest.inspect}"
        end
      end

      # optimize the parsed list
      tokens.pop while tokens.last == " "
      optimized = []
      tokens.each do |tok|
        last = optimized.last
        if tok.is_a?( BindVariable ) || last.nil? || last.is_a?( BindVariable )
          tok = Token.new(tok) if tok == " "
          optimized << tok
        else
          last << tok
        end
      end

      return optimized, scanner.rest
    end
    private :tokenize

  end

end
