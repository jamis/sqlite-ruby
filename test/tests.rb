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
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# =============================================================================
#++

$:.unshift "lib"

require 'test/unit/testsuite'
require 'fileutils'
require 'rbconfig'

Dir.chdir( File.dirname( __FILE__ ) )

# =============================================================================
# ENSURE THAT THE EXTENSION LIBRARY IS AVAILABLE AND UP-TO-DATE
# =============================================================================

FileUtils.mkdir_p "lib"

ext_lib = "lib/sqlite_api.#{Config::CONFIG['DLEXT']}"
ext_src = %w{ ../ext/sqlite-api.c ../ext/extconf.rb }
unless FileUtils.uptodate?( ext_lib, ext_src )
  FileUtils.mkdir_p "build", :verbose=>true
  FileUtils.cp ext_src, "build"
  FileUtils.cd( "build" ) do
    puts "Building extension library"
    system "ruby extconf.rb > /dev/null" or
      fail "could not configure SQLite/Ruby module"
    system "make > /dev/null" or
      fail "could not build SQLite/Ruby module"
  end
  FileUtils.cp "build/sqlite_api.#{Config::CONFIG['DLEXT']}", "lib",
    :verbose=>true
  FileUtils.rm_rf "build"
end

Dir["../lib/**/*.rb"].map { |i| i[3..-1] }.each do |file|
  unless FileUtils.uptodate?( file, "../#{file}" )
    dir = File.dirname( file )
    FileUtils.mkdir_p dir, :verbose=>true unless File.exist?( dir )
    FileUtils.cp "../#{file}", file, :verbose=>true
  end
end

# =============================================================================
# LOAD THE TEST CASES
# =============================================================================

Dir["**/tc_*.rb"].each { |file| load file }

class TS_AllTests
  def self.suite
    suite = Test::Unit::TestSuite.new( "All SQLite/Ruby Unit Tests" )

    ObjectSpace.each_object( Class ) do |unit_test|
      next unless unit_test.name =~ /^T[CS]_/ &&
        unit_test.superclass == Test::Unit::TestCase
      suite << unit_test.suite
    end

    return suite
  end
end

require 'test/unit/ui/console/testrunner'
test_runner = Test::Unit::UI::Console::TestRunner

case ARGV[0]
  when "GTK"
    require 'test/unit/ui/gtk/testrunner'
    test_runner = Test::Unit::UI::GTK::TestRunner
  when "GTK2"
    require 'test/unit/ui/gtk2/testrunner'
    test_runner = Test::Unit::UI::GTK2::TestRunner
  when "Fox"
    require 'test/unit/ui/fox/testrunner'
    test_runner = Test::Unit::UI::Fox::TestRunner
  when "Tk"
    require 'test/unit/ui/tk/testrunner'
    test_runner = Test::Unit::Tk::Fox::TestRunner
end

use_reporter = ARGV.find { |arg| arg.downcase == "report" }

if use_reporter
  begin
    require 'test/unit/util/reporter'
  rescue LoadError => l
    use_reporter = false
  end
end

FileUtils.rm_f "db/fixtures.db"
system "sqlite db/fixtures.db < db/fixtures.sql"

if use_reporter
  path = File.join( File.dirname( __FILE__ ), "..", "report" )
  FileUtils.mkdir_p path
  Test::Unit::Util::Reporter.run( test_runner, TS_AllTests.suite, path, :html )
  puts "An HTML report of these unit tests has been written to #{path}"
else
  test_runner.run( TS_AllTests )
end

FileUtils.rm_f "db/fixtures.db"
