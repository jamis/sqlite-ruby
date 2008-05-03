$:.unshift "lib"

require 'sqlite'
require 'test/unit'

begin

  require 'arrayfields'

  class TC_ArrayFields < Test::Unit::TestCase

    def setup
      @db = SQLite::Database.open( "db/fixtures.db" )
      @db.type_translation = true
    end

    def teardown
      @db.close
    end

    def test_fields
      row = @db.get_first_row "select * from A"
      assert_equal( [ "name", "age" ], row.fields )
    end

    def test_name_access
      row = @db.get_first_row "select * from A"
      assert_equal( "Zephyr", row["name"] )
      assert_equal( 1, row["age"] )
    end

    def test_index_access
      row = @db.get_first_row "select * from A"
      assert_equal( "Zephyr", row[0] )
      assert_equal( 1, row[1] )
    end

  end

rescue LoadError => e
  puts "'arrayfields' does not appear to exist... skipping arrayfields integration test"
end
