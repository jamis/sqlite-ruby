require "./lib/sqlite/version"

Gem::Specification.new do |s|

   s.name = 'sqlite-ruby'
   s.version = SQLite::Version::STRING
   s.platform = Gem::Platform::WIN32
   s.required_ruby_version = ">=1.8.0"

   s.summary = "SQLite/Ruby is a module to allow Ruby scripts to interface with a SQLite database."

   s.files = Dir.glob("{doc,ext,lib,test}/**/*").delete_if { |item| item.include?( "CVS" ) }
   s.files.concat [ "LICENSE", "README", "ChangeLog" ]

   s.require_path = 'lib'
   s.autorequire = 'sqlite'

   s.has_rdoc = true
   s.extra_rdoc_files = [ "README", "ext/sqlite-api.c" ]
   s.rdoc_options = [ "--main", "README" ]

   s.test_suite_file = "test/tests.rb"

   s.author = "Jamis Buck"
   s.email = "jgb3@email.byu.edu"
   s.homepage = "http://sqlite-ruby.rubyforge.org"

end
