require "./src/common_mark"
# require "./src/markdown/node"
# require "./src/markdown/blocks"

# if ARGV.empty?
#   puts "usage: cat somefile | egrep 'some'"
#   exit
# end

io = ""

while line = STDIN.gets
  io += line
end

puts CommonMark.to_html(io)








# parser = CommonMark::Parser.new
# # renderer = CommonMark::HtmlRenderer.new
# parsed = parser.parse io # parsed is a 'Node' tree
# # puts renderer.render parsed # result is a String
# puts parsed
