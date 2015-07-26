require "./common_mark/*"

module CommonMark

  def self.to_html(text)
    doc = parse(text)
    renderer = HTMLRenderer.new
    renderer.render doc
  end

  def self.parse(text)
    parser = Parser.new(text)
    parser.parse
  end
end
