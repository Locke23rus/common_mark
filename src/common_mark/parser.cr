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
      property parent
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
      property parent
      property content
      property children
      getter level

      def initialize(line, underline)
        @content = line.strip
        @level = underline.lstrip[0] == '=' ? 1 : 2
      end
    end

    class Paragraph
      property parent
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
      property parent
      property children
    end

    class FencedCodeBlock
      property parent
      property children
      property open
      getter info

      def initialize(line)
        @open = true
        @lines = [] of String
        @indent = 0
        line.each_char do |char|
          if char == ' '
            @indent += 1
          else
            break
          end
        end
        line = line.lstrip
        @fence_char = line[0]
        @fence_length = 0
        line.each_char do |char|
          if char == @fence_char
            @fence_length += 1
          else
            break
          end
        end
        @info = (line[@fence_length..-1].lstrip.split(/\s+/)).first?
      end

      def closing_code_fence
        @fence_char.to_s * @fence_length
      end

      def add_line(line)
        @lines << "#{line}\n"
      end

      def content
        stripped_lines.join
      end

      def stripped_lines
        if @indent > 0
          indent = " " * @indent
          if @lines.all? { |line| line.starts_with?(indent) }
            @lines.map { |line| line[@indent..-1] }
          else
            @lines.map do |line|
              n = 0
              while n < @indent && n < line.size && line[n] == ' '
                n += 1
              end
              line[n..-1]
            end
          end
        else
          @lines
        end
      end
    end

    class IndentedCodeBlock
      property parent
      property content
      property children

      def initialize
        @lines = [] of String

      end

      def add_line(line)
        line = strip(line)
        # drop preceding blank lines
        return if @lines.empty? && line.empty?
        @lines << "#{line}\n"
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

        line[i..-1]
      end

      def content
        # drop following blank lines
        n = @lines.size - 1
        while n >= 0 && @lines[n] == "\n"
          n -= 1
        end
        if n < 0
          ""
        else
          @lines[0..n].join
        end
      end
    end

    class Blockquote
      property parent
      property children

      def initialize
        @children = [] of ATXHeader | Paragraph | FencedCodeBlock | IndentedCodeBlock
      end
    end

    class Document
      property parent
      property children

      def initialize
        @children = [] of ATXHeader | SetextHeader| Paragraph | Hrule | FencedCodeBlock |
            IndentedCodeBlock | Blockquote
        @parent = self
      end
    end
  end

  class Parser
    RE_START_POUNDS = /^\s{0,3}[#]{1,6}(\s+|$)/
    RE_CLOSING_POUNDS = /\s+[#]+\s*$/
    RE_HRULE = /^[ ]{0,3}((([*][ ]*){3,})|(([-][ ]*){3,})|([_][ ]*){3,})[ \t]*$/
    RE_START_CODE_FENCE = /^[ ]{0,3}`{3,}(?!.*`)|^~{3,}(?!.*~)/
    RE_CLOSING_CODE_FENCE = /^[ ]{0,3}(`{3,}|~{3,})[ ]*$/
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
      elsif fenced_code_block? block, line
        process_fenced_code_block block, line
      elsif indented_code_block? block, line
        process_indented_code_block block, line
      else
        process_paragraph block, line
      end
    end

    def process_line
      line = @lines[@line]

      if fenced_code_block? @root, line
        process_fenced_code_block @root, line
      elsif blockquote? line
        process_blockquote @root
      elsif atx_header? line
        add_atx_header @root, line

      # TODO: HTML block

      elsif horizonal_rule? line
        add_horizontal_rule @root
      elsif setext_header?
        add_setext_header @root, line
      # TODO: list item

      elsif indented_code_block? @root, line
        process_indented_code_block @root, line
      else
        process_paragraph @root, line
      end
    end

    def paragraph?(block, line)
      return false if blockquote?(line) || atx_header?(line)
      return false if fenced_code_block?(block, line) || horizonal_rule?(line)
      return false if setext_header?
      return false if indented_code_block?(block, line)
      true
    end

    def blockquote?(line)
      line =~ RE_BLOCKQUOTE
    end

    def atx_header?(line)
      RE_START_POUNDS =~ line
    end

    def fenced_code_block?(block, line)
      node = @current
      return true if node.is_a?(Node::FencedCodeBlock) && node.open && node.parent == block
      RE_START_CODE_FENCE =~ line
    end

    def horizonal_rule?(line)
      RE_HRULE =~ line
    end

    def setext_header?
      node = @current
      return false if node.is_a?(Node::Paragraph) && node.open
      @lines[@line] =~ RE_SETEXT_HEADER_TEXT && next_line =~ RE_SETEXT_HEADER_LINE
    end

    def next_line
      @lines[@line + 1]?
    end

    def blank_line?(line)
      line == "" || RE_BLANK_LINE =~ line
    end

    def indented_code_block?(block, line)
      node = @current
      return false if node.is_a?(Node::Paragraph) && node.open
      return true if node.is_a?(Node::IndentedCodeBlock) && blank_line?(line) && node.parent == block
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

    def add_horizontal_rule(block)
      node = Node::Hrule.new
      append block, node
      @current = node
      @line += 1
    end

    def add_setext_header(block, line)
      node = Node::SetextHeader.new line, next_line.not_nil!
      append block, node
      @current = node
      @line += 2
    end

    def add_fenced_code_block(block, line)
      node = Node::FencedCodeBlock.new line
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

    def process_blockquote(block)
      node = Node::Blockquote.new
      append block, node
      @current = node
      while @line < @lines.length
        if blockquote?(@lines[@line])
          process_inlines node, @lines[@line].gsub(RE_BLOCKQUOTE, "")
        else
          current_node = @current
          if current_node.is_a?(Node::Paragraph) && current_node.open
            if blank_line?(@lines[@line])
              current_node.open = false
              @line += 1
            elsif paragraph?(block, @lines[@line])
              current_node.add_line @lines[@line]
              @line += 1
            else
              break
            end
          else
            break
          end
        end
      end
    end

    def process_fenced_code_block(block, line)
      node = @current
      if node.is_a?(Node::FencedCodeBlock) && node.open
        if RE_CLOSING_CODE_FENCE =~ line && line.rstrip.ends_with?(node.closing_code_fence)
          node.open = false
        else
          node.add_line line
        end
        @line += 1
      else
        add_fenced_code_block block, line
      end
    end

    def append(block, node)
      case block
      when Node::Document, Node::Blockquote
        block.children << node
        node.parent = block
      end
    end

    def process_indented_code_block(block, line)
      node = @current
      if node.is_a?(Node::IndentedCodeBlock) && node.parent == block
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
