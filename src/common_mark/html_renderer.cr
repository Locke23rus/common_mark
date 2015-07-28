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

  def render_node(io, node : CommonMark::Node::Header)
    io << "<h#{node.level}>#{node.content}</h#{node.level}>\n"
  end

  def render_node(io, node : CommonMark::Node::Paragraph)
    io << "<p>#{node.content}</p>\n"
  end

  def render_node(io, node : CommonMark::Node::Hrule)
    io << "<hr />\n"
  end

  def render_node(io, node : CommonMark::Node::FencedCodeBlock | CommonMark::Node::IndentedCodeBlock)
    io << "<pre><code>"
    io << HTML.escape node.content
    io << "</code></pre>"
  end
end
