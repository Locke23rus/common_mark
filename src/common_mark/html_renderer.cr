require "html"

class CommonMark::HTMLRenderer

  def render(document)
    html = String.build do |io|
      document.children.each do |node|
        render_node io, node
      end
    end
    html.chomp
  end

  def h(*args)
    HTML.escape *args
  end

  def render_node(io, node : CommonMark::Node::ATXHeader | CommonMark::Node::SetextHeader)
    io << "<h#{node.level}>#{h node.content}</h#{node.level}>\n"
  end

  def render_node(io, node : CommonMark::Node::Paragraph)
    io << "<p>"

    count = node.lines.size - 1
    node.lines.each_with_index do |line, i|
      if i == count
        io << h line.strip
      elsif line.ends_with?("  ")
        io <<"#{h line.rstrip}<br />\n"
      else
        io << "#{h line.strip}\n"
      end
    end
    io << "</p>\n"
  end

  def render_node(io, node : CommonMark::Node::Hrule)
    io << "<hr />\n"
  end

  def render_node(io, node : CommonMark::Node::FencedCodeBlock | CommonMark::Node::IndentedCodeBlock)
    io << "<pre><code>"
    io << h node.content
    io << "</code></pre>\n"
  end

  def render_node(io, node : CommonMark::Node::Blockquote)
    io << "<blockquote>\n"
    node.children.each do |node|
      render_node io, node
    end
    io << "</blockquote>\n"
  end
end
