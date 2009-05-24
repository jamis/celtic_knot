require 'celtic_knot/bezier'
require 'celtic_knot/edge'
require 'celtic_knot/knot'
require 'celtic_knot/line'
require 'celtic_knot/node'
require 'celtic_knot/triangle'

module CelticKnot
  class Graph
    def self.parse(io)
      nodes = {}

      io.each_line do |line|
        line = line.sub(/#.*$/, "").strip
        next if line.empty?

        if line =~ /^\s*(\w+)\s*:\s*(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$/
          name = $1.downcase
          x = $2.to_f
          y = $3.to_f
          nodes[name] = Node.new(x,y)
        elsif line =~ /^\s*(\w+)\s*(\S)\s*(\w+)\s*$/
          p1 = nodes[$1.downcase] or abort "unknown point #{$1}"
          type = $2
          p2 = nodes[$3.downcase] or abort "unknown point #{$2}"
          Edge.new(p1, p2, type)
        else
          raise "can't parse: #{line.inspect}"
        end
      end

      new(nodes.values)
    end

    attr_reader :nodes

    def initialize(nodes)
      @nodes = nodes
    end

    def construct_knot
      knot = Knot.new

      near = nodes.first
      edge = near.edges.first
      far = edge.other(near)
      pass = 0

      loop do
        if edge.finished?
          near = nodes.detect { |n| n.edges.any? { |e| !e.finished? } }
          break unless near
          edge = near.edges.detect { |e| !e.finished? }
          far = edge.other(near)
          pass = 0
        end

        if edge.marked?(near)
          far, near = near, edge.other(near)
        end

        edge.mark(near)

        d = near.direction_to(far)
        perp = d.cross_right

        if far.edges.length == 1
          near, edge = process_deadend(knot, edge, near, far, d, perp)
        elsif far.edges.length == 2
          near, edge = process_corner(knot, edge, near, far, d, perp)
        else
          near, edge = process_intersection(knot, edge, near, far, d, perp)
        end

        far = edge.other(near)
      end

      return knot
    end

    def to_svg(options={})
      svg = "<g>\n"

      edges = nodes.map { |node| node.edges }.flatten.uniq
      edges.each { |edge| svg << edge.to_svg(options) << "\n" }
      nodes.each { |node| svg << node.to_svg(options) << "\n" }

      svg << "</g>\n"
    end

    private

      def process_deadend(knot, edge, near, far, d, perp)
        lperp = perp.inverse
        direction = far - edge.midpoint
        distance = direction.length
        curve_mid = far + direction

        outgoing_vector = d.between(perp).normalize

        points = [edge.midpoint, edge.midpoint + outgoing_vector * distance, curve_mid + perp * distance, curve_mid]
        knot.add(edge, points, true)

        incoming_vector = d.between(lperp).normalize

        points = [curve_mid, curve_mid + lperp * distance, edge.midpoint + incoming_vector * distance, edge.midpoint]
        knot.add(edge, points, false)

        return [near, edge]
      end

      def process_corner(knot, edge, near, far, d, perp)
        edge2 = far.edges_without(edge).first
        process_corner_with_edges(knot, edge, edge2, near, far, d, perp)
      end

      def process_intersection(knot, edge, near, far, d, perp)
        edge2 = far.nearest_edge_to(edge)
        process_corner_with_edges(knot, edge, edge2, near, far, d, perp)
      end

      def process_corner_with_edges(knot, edge, edge2, near, far, d, perp)
        far2 = edge2.other(far)
        d2 = far.direction_to(far2)
        perp2 = d2.cross_right

        if d == d2 # the two edges are colinear
          direction = perp * (far - edge.midpoint).length
        else
          triangle = Triangle.new(near, far, far2)
          direction = far - triangle.centroid
        end

        outgoing_vector = d.between(perp).normalize
        incoming_vector = d2.between(perp2).normalize.cross_right

        if triangle && triangle.contains?(edge.midpoint + perp*0.01)
          # where do the vectors intersect?
          l1 = Line.new(edge.midpoint, edge.midpoint + outgoing_vector)
          l2 = Line.new(edge2.midpoint, edge2.midpoint + incoming_vector)

          pmid = l1.intersect(l2) || (edge.midpoint + edge2.midpoint) / 2

          curve = Bezier.new([edge.midpoint, pmid, pmid, edge2.midpoint])
          over, under = curve.split(0.5)

          knot.add(edge, over.controls, true)
          knot.add(edge2, under.controls, false)
        else
          meetup = far + direction

          l1 = (far - edge.midpoint).length / 2
          l2 = (far - edge2.midpoint).length / 2

          points = [edge.midpoint, edge.midpoint + outgoing_vector * l1,
            meetup + direction.cross_right.normalize * l1, meetup]
          knot.add(edge, points, true)
          
          points = [meetup, meetup + direction.cross_left.normalize * l2,
            edge2.midpoint + incoming_vector * l2, edge2.midpoint]
          knot.add(edge2, points, false)
        end

        return [far, edge2]
      end
  end
end
