module CommonMark
  module Node
    enum Type
  	# Error status
  	NONE

  	# Block
  	DOCUMENT
  	BLOCK_QUOTE
  	LIST
  	ITEM
  	CODE_BLOCK
  	HTML
  	PARAGRAPH
  	HEADER
  	HRULE

  	FIRST_BLOCK = DOCUMENT
  	LAST_BLOCK  = HRULE

  	# Inline
  	TEXT
  	SOFTBREAK
  	LINEBREAK
  	CODE
  	INLINE_HTML
  	EMPH
  	STRONG
  	LINK
  	IMAGE

  	FIRST_INLINE = TEXT
  	LAST_INLINE  = IMAGE
  end

    class Header
      property content
      property children
      getter level
      property setext

      def initialize(@line)
        @setext = false
        @level = 0
        n = line.index('#').not_nil!
        while line[n] == '#'
          n += 1
          @level += 1
        end

        @content = line.gsub /\s*\#+\s*/, ""
      end
    end

    class Paragraph
      property content
      property children

      def initialize(line)
        @content = line.strip
      end
    end

    class Document
      property content
      property children

      def initialize
        @content = ""
        @children = [] of Header | Paragraph
      end
    end
  end

  class Parser
    def initialize(text)
      @root = Node::Document.new
      @current = @root
      @lines = text.lines.map &.chomp
      @line = 0
    end

    def process_line
      line = @lines[@line]

      # if line.starts_with?('#')
      if /\s{0,3}\#{1,6}\s/ =~ line
        node = Node::Header.new line
        @root.children << node
        @current = node
        @line += 1
      elsif @current.is_a?(Node::Paragraph)
        @current.content += "\n#{line}"
        @line += 1
      else
        node = Node::Paragraph.new line
        @root.children << node
        @current = node
        @line += 1
      end
    end

    def parse
      while @line < @lines.length
        process_line
      end

      @root
    end
  end
end
