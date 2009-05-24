module CelticKnot
  class Path
    attr_reader :elements

    def initialize(*elements)
      @elements = elements
    end

    def add(element)
      elements.push(element)
      self
    end

    def to_svg(options={})
      options = options.merge(:id => "p#{object_id}")
      svg = '<path d="' << elements.map { |e| e.to_svg_path(options) }.join(" ") << '" '
      options.each { |k,v| svg << " #{k}=\"#{v}\"" }
      svg << " />"
    end
  end
end
