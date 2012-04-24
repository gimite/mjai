$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")

require "erb"
require "fileutils"

include(ERB::Util)


if !system("coffee -cb html_res/js/archive_player.coffee")
  exit(1)
end
if !system("coffee -cb html_res/js/dytem.coffee")
  exit(1)
end
if !system("sass html_res/css/style.scss html_res/css/style.css")
  exit(1)
end
archive_path = ARGV[0]
html_path = ARGV[1]
base_name = File.basename(html_path)
action_jsons = File.readlines(archive_path).map(){ |s| s.chomp().gsub(/\//){ "\\/" } }
actions_json = "[%s]" % action_jsons.join(",\n")
html = ERB.new(File.read(File.dirname(__FILE__) + "/../html_res/archive_player.erb"), nil, "<>").
    result(binding)
open(html_path, "w"){ |f| f.write(html) }
for src_path in Dir["html_res/css/*.css"] + Dir["html_res/js/*.js"]
  dest_path = src_path.gsub(/^html_res\//){ "#{html_path}.files/" }
  FileUtils.mkdir_p(File.dirname(dest_path))
  FileUtils.cp(src_path, dest_path)
end
