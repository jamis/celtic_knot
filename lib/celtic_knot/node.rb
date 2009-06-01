require 'celtic_knot/point'

module CelticKnot
  class Node < Point
    attr_reader :edges

    def initialize(x, y)
      super(x,y)
      @edges = []
    end

    def edges_without(edge)
      edges.reject { |e| e == edge }
    end

    def nearest_edge_to(edge)
      smallest_angle = 2*Math::PI
      nearest_edge = nil

      vector = edge.other(self).direction_to(self)

      list = edges_without(edge)
      list.each do |e2|
        vector2 = self.direction_to(e2.other(self))
        angle = vector.angle(vector2)
        if angle < smallest_angle
          smallest_angle = angle
          nearest_edge = e2
        end
      end

      return nearest_edge
    end

    def to_svg(options={})
      color = options[:color] || "black"
      '<circle cx="%f" cy="%f" r="1" fill="%s" stroke="%s" />' % [x, y, color, color]
    end
  end
end
