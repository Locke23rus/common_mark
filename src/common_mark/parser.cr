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

    class ATXHeader
      property content
      property children
      getter level

      def initialize(line)
        @level = 0
        n = line.index('#').not_nil!
        size = line.length
        while n < size && line[n] == '#'
          n += 1
          @level += 1
        end

        @content = line.gsub(Parser::RE_CLOSING_POUNDS, "").
          gsub(Parser::RE_START_POUNDS, "")
      end
    end

    class SetextHeader
      property content
      property children
      getter level

      def initialize(line, underline)
        @content = line.strip
        @level = underline.lstrip[0] == '=' ? 1 : 2
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

    class Blockquote
      property children

      def initialize
        @children = [] of ATXHeader | Paragraph | IndentedCodeBlock
      end
    end

    class Document
      property children

      def initialize
        @children = [] of ATXHeader | SetextHeader| Paragraph | Hrule | FencedCodeBlock |
            IndentedCodeBlock | Blockquote
      end
    end
  end

  class Parser
    RE_START_POUNDS = /^\s{0,3}[#]{1,6}(\s+|$)/
    RE_CLOSING_POUNDS = /\s+[#]+\s*$/
    RE_HRULE = /^[ ]{0,3}((([*][ ]*){3,})|(([-][ ]*){3,})|([_][ ]*){3,})[ \t]*$/
    RE_START_CODE_FENCE = /^`{3,}(?!.*`)|^~{3,}(?!.*~)/
    RE_CLOSING_CODE_FENCE = /^(?:`{3,}|~{3,})(?= *$)/
    RE_BLANK_LINE = /^[ \t]*$/
    RE_SETEXT_HEADER_TEXT = /^[ ]{0,3}\S+/
    RE_SETEXT_HEADER_LINE = /^[ ]{0,3}([=]+|[-]{2,})[ ]*$/
    RE_BLOCKQUOTE = /^[ ]{0,3}>[ ]?/

    def initialize(text)
      @root = Node::Document.new
      @current = @root
      @lines = text.lines.map &.chomp
      @line = 0
    end

    def process_inlines(block, line)
      if atx_header? line
        add_atx_header block, line
      elsif can_break? && indented_code_block? line
        process_indented_code_block block, line
      else
        process_paragraph block, line
      end
    end

    def process_line
      line = @lines[@line]

      if blockquote? line
        process_blockquote
      elsif atx_header? line
        add_atx_header @root, line
      elsif fenced_code_block? line
        process_fenced_code_block

      # TODO: HTML block

      elsif horizonal_rule? line
        node = Node::Hrule.new
        @root.children << node
        @current = node
        @line += 1
      elsif can_break? && setext_header?
        node = Node::SetextHeader.new line, next_line.not_nil!
        @root.children << node
        @current = node
        @line += 2

      # TODO: list item

      elsif can_break? && indented_code_block? line
        process_indented_code_block @root, line
      else
        process_paragraph @root, line
      end
    end

    def paragraph?(line)
      return false if blockquote?(line) || atx_header?(line) || fenced_code_block?(line) || horizonal_rule?(line)
      return false if can_break? && setext_header?
      return false if can_break? && indented_code_block?(line)
      true
    end

    def blockquote?(line)
      line =~ RE_BLOCKQUOTE
    end

    def atx_header?(line)
      RE_START_POUNDS =~ line
    end

    def fenced_code_block?(line)
      RE_START_CODE_FENCE =~ line
    end

    def horizonal_rule?(line)
      RE_HRULE =~ line
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

    def setext_header?
      @lines[@line] =~ RE_SETEXT_HEADER_TEXT && next_line =~ RE_SETEXT_HEADER_LINE
    end

    def next_line
      @lines[@line + 1]?
    end

    def blank_line?(line)
      line == "" || RE_BLANK_LINE =~ line
    end

    def indented_code_block?(line)
      line.gsub('\t', "    ").starts_with?("    ")
    end

    def add_paragraph(block, line)
      node = Node::Paragraph.new
      node.add_line line
      append block, node
      @current = node
    end

    def add_atx_header(block, line)
      node = Node::ATXHeader.new line
      append block, node
      @current = node
      @line += 1
    end

    def process_paragraph(block, line)
      node = @current
      case node
      when Node::Paragraph
        if blank_line? line
          node.open = false
        elsif node.open
          node.add_line line
        else
          add_paragraph block, line
        end
      else
        unless blank_line?(line)
          add_paragraph block, line
        end
      end
      @line += 1
    end

    def process_blockquote
      node = Node::Blockquote.new
      @root.children << node
      @current = node
      while @line < @lines.length
        if blockquote?(@lines[@line])
          process_inlines node, @lines[@line].gsub(RE_BLOCKQUOTE, "")
        else
          current_node = @current
          if current_node.is_a?(Node::Paragraph) && current_node.open && paragraph?(@lines[@line])
            current_node.add_line @lines[@line]
            @line += 1
          else
            break
          end
        end
      end
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

    def append(block, node)
      case block
      when Node::Document, Node::Blockquote
        block.children << node
      end
    end

    def process_indented_code_block(block, line)
      node = @current
      if node.is_a?(Node::IndentedCodeBlock)
        node.add_line line
      else
        node = Node::IndentedCodeBlock.new
        node.add_line line
        append block, node
        @current = node
      end
      @line += 1
    end

    def parse
      while @line < @lines.length
        process_line
      end
      @root
    end
  end
end
