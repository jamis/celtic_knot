module CelticKnot
  class Edge
    def self.class_for(type)
      case type
      when ',' then NormalEdge
      when '-' then IgnoredEdge
      when '=' then ImperviousEdge
      else raise ArgumentError, "expected one of (',', '-', '=') for edge type"
      end
    end

    attr_reader :n1, :n2
    attr_reader :type
    attr_reader :passes

    def initialize(n1, n2)
      @n1, @n2 = n1, n2

      n1.add_edge(self)
      n2.add_edge(self)

      @marked = {}
      @intersections = 0
    end

    def mark(point, direction)
      raise "already marked #{point} on #{self}" if @marked[[point, direction]]
      mark_near(point, direction)
      mark_opposite(point, direction)
      @intersections += 1
    end

    def marked?(point, direction)
      @marked[[point, direction]]
    end

    def finished?
      @intersections == 2
    end

    def midpoint
      @midpoint ||= Curves::Point.new((n1.x + n2.x)/2.0, (n1.y + n2.y)/2.0)
    end

    def length
      (n1 - n2).length
    end

    def other(node)
      node == n1 ? n2 : n1
    end

    def angle_to(edge, direction=Direction::CCW)
      common = ([edge.n1, edge.n2] & [n1, n2]).first
      vector1 = other(common) - common
      vector2 = edge.other(common) - common
      result = vector1.angle(vector2)
      result = 2 * Math::PI - result if direction.cw?
      return result
    end

    # Returns a number from 0.0 (edge is the same as self) to 1.0
    # (edge are 360 degrees rotated in the given direction). Two
    # colinear edges will have a difference of 0.5 (180 degrees).
    def difference(edge, direction=Direction::CCW)
      angle_to(edge, direction) / (2 * Math::PI)
    end

    def normal?
      false
    end

    def ignore?
      false
    end

    def impervious?
      false
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

    private

      def mark_near(point, direction)
        @marked[[point, direction]] = true
      end
  end


  class NormalEdge < Edge
    # Return the "virtual" midpoint.
    #
    # This will be the natural midpoint of the edge. The reference, direction,
    # and phase parameters are all ignored for normal edges.
    def virtual_midpoint(reference, direction, phase)
      midpoint
    end

    def vector(parallel, direction)
      parallel.between(direction.cw? ? parallel.rotate_ccw : parallel.rotate_cw)
    end

    def normal?
      true
    end

    def to_s
      "<%s,%s>" % [n1, n2]
    end

    private

      def mark_opposite(point, direction)
        far = other(point)
        @marked[[far, direction]] = true
      end
  end


  class ImperviousEdge < Edge
    # Return the "virtual" midpoint.
    #
    # This will be a point offset some distance from the natural midpoint,
    # perpendicular to the edge. In this case, the direction parameter is
    # used to determine which side of the edge the point is offset from; if
    # direction is Direction::CW (clockwise), it will be offset as though it
    # were going to orbit in a clockwise direction around the reference node.
    # Likewise, if the direction is Direction::CCW (counter-clockwise) it will
    # be offset as thought it were going to orbit the reference node in a
    # counter-clockwise direction. The phase parameter is ignored, in either
    # case.
    def virtual_midpoint(reference, direction, phase)
      vector = midpoint - reference
      vector = direction == Direction::CCW ? vector.rotate_cw : vector.rotate_ccw
      return midpoint + vector.normalize * length/4 # FIXME: don't hard-code the cable width
    end

    def vector(parallel, direction)
      parallel
    end

    def impervious?
      true
    end

    def to_s
      "<%s=%s>" % [n1, n2]
    end

    private

      def mark_opposite(point, direction)
        far = other(point)
        @marked[[far, direction.opposite]] = true
      end
  end


  class IgnoredEdge < Edge
    # Return the "virtual" midpoint.
    #
    # This will be a point offset some distance from the natural midpoint,
    # colinear with the edge. In this case, the direction parameter is
    # ignored, and the midpoint returned will always be the one nearest the
    # reference node if phase is :enter, and the furthest if phase is :start.
    def virtual_midpoint(reference, direction, phase)
      direction = (midpoint - reference).normalize

      if phase == :start
        return reference + direction * 0.75 * length
      elsif phase == :enter
        return reference + direction * 0.25 * length
      else
        raise ArgumentError, "unknown phase: #{phase.inspect}"
      end
    end

    def vector(parallel, direction)
      if direction.cw?
        parallel.rotate_ccw
      else
        parallel.rotate_cw
      end
    end

    def ignore?
      true
    end

    def to_s
      "<%s-%s>" % [n1, n2]
    end

    private

      def mark_opposite(point, direction)
      end

      def mark_near(point, direction)
        @marked[[point, direction]] = true
        @marked[[point, direction.opposite]] = true
      end
  end
end
