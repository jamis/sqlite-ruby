require 'fileutils'

FileUtils.mkdir_p "build"

FileUtils.cp %w{ext/extconf.rb ext/sqlite-api.c}, "build", :verbose => true
FileUtils.cp_r "lib", "build", :verbose => true

FileUtils.cd( "build", :verbose => true ) do
  extconf_args = ARGV.map { |a| a.inspect }.join( " " )

  unless system( "ruby extconf.rb #{extconf_args}" )
    puts "could not configure sqlite module"
    exit
  end

  unless system( "make" )
    puts "could not build sqlite module"
    exit
  end

  unless system( "make install" )
    puts "could not install sqlite module"
    exit
  end
end

FileUtils.rm_r "build", :verbose => true
