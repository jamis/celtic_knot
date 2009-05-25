module CelticKnot
  class Edge
    attr_reader :n1, :n2
    attr_reader :type
    attr_reader :passes

    def initialize(n1, n2, type)
      @n1, @n2, @type = n1, n2, type

      n1.edges << self
      n2.edges << self

      @marked = []
    end

    def mark(n)
      raise ArgumentError, "node is not part of edge" unless n1 == n || n2 == n
      raise "already marked #{n} for #{self}" if @marked.include?(n)
      @marked << n
    end

    def marked?(n)
      @marked.include?(n)
    end

    def finished?
      !normal? || @marked.length == 2
    end

    def midpoint
      @midpoint ||= n1 + (n2 - n1)/2.0
    end

    def other(node)
      node == n1 ? n2 : n1
    end

    def where_is(point)
      point.y - n1.y - (point.x - n1.x) * ((n2.y - n1.y).to_f / (n2.x - n1.x))
    end

    def normal?
      type == ","
    end

    def ignore?
      type == "-"
    end

    def impervious?
      type == "="
    end

    def to_s
      "<%p%s%p>" % [n1, type, n2]
    end

    def to_svg(options={})
      color = options[:color] || "black"
      svg = '<path d="'
      svg << "M #{n1.x} #{n1.y} L #{n2.x} #{n2.y}"
      svg << '" '
      svg << 'stroke="%s" fill="none" stroke-width="1"' % color
      svg << " />"
    end
  end
end
