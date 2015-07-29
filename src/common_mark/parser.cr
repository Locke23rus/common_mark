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
      property children
      property open
      getter lines

      def initialize
        @lines = [] of String
        @open = true
      end

      def add_line(line)
        lines << line
      end
    end

    class Hrule
      property children
    end

    class FencedCodeBlock
      property content
      property children
      getter fence_char

      def initialize(line)
        @fence_char = line.lstrip[0]
        @content = ""
      end

      def add_line(line)
        @content += "#{line.rstrip}\n"
      end
    end

    class IndentedCodeBlock
      property content
      property children

      def initialize
        @content = ""
      end

      def add_line(line)
        @content += "#{strip(line)}\n"
      end

      def strip(line)
        i = 0

        while i < 4 && i < line.length
          if line[i] == ' '
            i += 1
          elsif line[i] == '\t'
            i += 1
            break
          else
            break
          end
        end

        line[i..-1].rstrip
      end
    end

    class Document
      property children

      def initialize
        @children = [] of Header | Paragraph | Hrule | FencedCodeBlock | IndentedCodeBlock
      end
    end
  end

  class Parser
    RE_ATX_HEADER = /\s{0,3}\#{1,6}\s/
    RE_HRULE = /^[ ]{0,3}((([*][ ]*){3,})|(([-][ ]*){3,})|([_][ ]*){3,})[ \t]*$/
    RE_START_CODE_FENCE = /^`{3,}(?!.*`)|^~{3,}(?!.*~)/
    RE_CLOSING_CODE_FENCE = /^(?:`{3,}|~{3,})(?= *$)/
    RE_BLANK_LINE = /^[ \t]*$/

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
        process_fenced_code_block

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
      elsif indented_code_block?(line) && can_break?
        process_indented_code_block
      else
        node = @current
        case node
        when Node::Paragraph
          if line == "" || RE_BLANK_LINE =~ line
            node.open = false
          elsif node.open
            node.add_line line
          else
            add_paragraph(line)
          end
        else
          add_paragraph(line)
        end

        @line += 1
      end
    end

    def can_break?
      node = @current
      case node
      when Node::Paragraph
        !node.open
      else
        true
      end
    end

    def indented_code_block?(line)
      line.gsub('\t', "    ").starts_with?("    ")
    end

    def add_paragraph(line)
      node = Node::Paragraph.new
      node.add_line line
      @root.children << node
      @current = node
    end

    def process_fenced_code_block
      node = Node::FencedCodeBlock.new @lines[@line]
      @root.children << node
      @current = node
      @line += 1

      while @line < @lines.length &&
        !(RE_CLOSING_CODE_FENCE =~ @lines[@line] &&
         @lines[@line].length > 0 && @lines[@line][0] == node.fence_char)

        node.add_line @lines[@line]
        @line += 1
      end
      @line += 1
    end

    def process_indented_code_block
      node = Node::IndentedCodeBlock.new
      node.add_line @lines[@line]
      @root.children << node
      @current = node
      @line += 1

      while @line < @lines.length && indented_code_block?(@lines[@line])
        node.add_line @lines[@line]
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
