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

    class Hrule
      property content
      property children

      def initialize
        @content = ""
      end
    end

    class CodeBlock
      property content
      property children
      property fenced
      getter fence_char

      def initialize(line, @fenced = false)
        if fenced
          @fence_char = line[0]
          @content = line[3..-1]
        else
          @content = line.strip
        end
      end
    end

    class Document
      property content
      property children

      def initialize
        @content = ""
        @children = [] of Header | Paragraph | Hrule | CodeBlock
      end
    end
  end

  class Parser
    RE_ATX_HEADER = /\s{0,3}\#{1,6}\s/
    RE_HRULE = /^(?:(?:\* *){3,}|(?:_ *){3,}|(?:- *){3,}) *$/
    RE_START_CODE_FENCE = /^`{3,}(?!.*`)|^~{3,}(?!.*~)/
    RE_CLOSING_CODE_FENCE = /^(?:`{3,}|~{3,})(?= *$)/

    def initialize(text)
      @root = Node::Document.new
      @current = @root
      @lines = text.lines.map &.chomp
      @line = 0
    end

    def process_line
      line = @lines[@line]

      # TODO: block quote

      # ATX header
      if RE_ATX_HEADER =~ line
        node = Node::Header.new line
        @root.children << node
        @current = node
        @line += 1

      # Fenced code block
      elsif RE_START_CODE_FENCE =~ line
        node = Node::CodeBlock.new line, true
        @root.children << node
        @current = node
        @line += 1

        while @line < @lines.length &&
            !(RE_CLOSING_CODE_FENCE =~ @lines[@line] &&
                @lines[@line][0] == node.fence_char)

          add_line
          @line += 1
        end
        @line += 1

      # TODO: HTML block
      # TODO: Setext header

      # Horizonal rule
      elsif RE_HRULE =~ line
        node = Node::Hrule.new
        @root.children << node
        @current = node
        @line += 1

      # TODO: list item
      # TODO: indented code block

      elsif accepts_line?
        add_line
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

    def add_line
      @current.content += "\n#{@lines[@line]}"
    end

    def accepts_line?
      case @current
      when Node::Paragraph, Node::CodeBlock
        true
      else
        false
      end
    end
  end
end
