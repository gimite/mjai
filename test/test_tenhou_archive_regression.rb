$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "fileutils"
require "test/unit"


class TC_TenhouArchive < Test::Unit::TestCase
    
    def test_regression()
      FileUtils.mkdir_p("tmp")
      if !system("ruby bin/dump_archive.rb test/test.mjlog > tmp/test.mjlog.log")
        raise("execution failed")
      end
      assert(File.read("tmp/test.mjlog.log") == File.read("test/test.mjlog.golden.log"))
    end
    
end
