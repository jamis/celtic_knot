require 'celtic_knot/point'

module CelticKnot
  class Line
    DELTA = 0.0001

    attr_reader :p1, :p2

    def initialize(p1, p2)
      @p1, @p2 = p1, p2
    end

    def parallel?(line)
      return line.slope.nil? if slope.nil?
      return false if line.slope.nil?
      (slope - line.slope).abs < DELTA
    end

    def intersect(line)
      return nil if parallel?(line)

      denom = ((line.p2.y - line.p1.y) * (p2.x - p1.x) - (line.p2.x - line.p1.x) * (p2.y - p1.y)).to_f
      ua = ((line.p2.x - line.p1.x) * (p1.y - line.p1.y) - (line.p2.y - line.p1.y) * (p1.x - line.p1.x)) / denom

      x = p1.x + ua * (p2.x - p1.x)
      y = p1.y + ua * (p2.y - p1.y)

      return Point[x,y]
    end

    def slope
      return nil if p1.x == p2.x
      @slope ||= (p2.y - p1.y) / (p2.x - p1.x)
    end
  end
end
