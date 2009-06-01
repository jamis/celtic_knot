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
      @marked.length == 2
    end

    def midpoint
      @midpoint ||= n1 + (n2 - n1)/2.0
    end

    def virtual_midpoint(from, mode)
      if normal?
        return midpoint
      elsif impervious?
        direction = from.direction_to(midpoint)
        return midpoint + direction.cross_right * 5 # FIXME: don't hard-code the cable width
      elsif ignore?
        direction = from.direction_to(midpoint)
        distance = (midpoint - from).length
        offset = (mode == :incoming ? -3 : 3) # FIXME: don't hardcode the cable width
        return from + direction * (distance + offset)
      end
    end

    def vector(direction, mode)
      if normal?
        result = direction.between(direction.cross_right).normalize
        result = result.cross_right if mode == :incoming
      elsif impervious?
        result = mode == :outgoing ? direction : direction.inverse
      elsif ignore?
        result = direction.cross_right
      end

      return result
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

      width = impervious? ? 2 : 1
      dasharray = ignore? ? "3,3" : "none"

      svg = '<path d="'
      svg << "M #{n1.x} #{n1.y} L #{n2.x} #{n2.y}"
      svg << '" '
      svg << 'stroke="%s" fill="none" stroke-width="%s" stroke-dasharray="%s"' % [color, width, dasharray]
      svg << " />"
    end
  end
end
