require 'mkmf'

dir_config( "sqlite", "/usr/local", "/usr/local" )
have_library( "sqlite" )

if have_header( "sqlite.h" ) and have_library( "sqlite", "sqlite_open" )
  create_makefile( "sqlite_api" )
end
