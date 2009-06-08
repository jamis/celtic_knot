require 'curves/point'
require 'celtic_knot/direction'

module CelticKnot
  class Node < Curves::Point
    attr_reader :edges

    def initialize(x, y, z=0)
      super(x,y,z)
      @edges = []
    end

    def edges_without(edge)
      edges.reject { |e| e == edge }
    end

    def sort_edges!
      if edges.length > 2
        first = edges.first
        angles = edges.inject({}) { |h,e| h[e] = first.angle_to(e); h }
        edges.sort! { |a,b| angles[a] <=> angles[b] }
      end
    end

    def add_edge(edge)
      edges << edge
      sort_edges!
      return edge
    end

    # direction must be one of:
    # * Direction::CW -- clockwise
    # * Direction::CCW -- counter-clockwise
    #
    # assumes that the edges are in sorted order
    def nearest_edge_to(edge, direction)
      idx = edges.index(edge) or raise "edge #{e} is not attached to #{self}"
      nearest = direction == Direction::CW ? idx-1 : idx+1
      nearest = edges.length-1 if nearest < 0
      nearest = 0 if nearest >= edges.length
      return edges[nearest]
    end
  end
end
