$:.unshift "lib"

require 'sqlite'
require 'test/unit'

class TC_TypeTranslation < Test::Unit::TestCase

  def setup
    @db = SQLite::Database.open( "db/fixtures.db" )
    @db.type_translation = true
  end

  def teardown
    @db.close
  end

  def test_execute_no_block
    rows = @db.execute( "select * from A order by name limit 2" )

    assert_equal [ [nil, 6], ["Amber", 5] ], rows
  end

end
