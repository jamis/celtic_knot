require 'strscan'

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
        else
          scanner = StringScanner.new(line.strip)
          near = scanner.scan(/\w+/) or abort "expected node id on #{line.inspect}"
          p1 = nodes[near.downcase] or abort "unknown point #{near.inspect}"

          loop do
            scanner.skip(/\s*/)
            break if scanner.eos?
            type = scanner.scan(/[-,=]/) or abort "expected edge type on #{line.inspect}"
            scanner.skip(/\s*/)
            far = scanner.scan(/\w+/) or abort "expected node id on #{line.inspect}"
            p2 = nodes[far.downcase] or abort "unknown point #{far.inspect}"
            Edge.new(p1, p2, type)
            p1 = p2
          end
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
        edge2 = far.real_edges_without(edge).first
        process_corner_with_edges(knot, edge, edge2, near, far, d, perp)
      end

      def process_intersection(knot, edge, near, far, d, perp)
        edge2 = far.nearest_edge_to(edge)
        process_corner_with_edges(knot, edge, edge2, near, far, d, perp)
      end

      def process_corner_with_edges(knot, edge, edge2, near, far, d, perp)
        return process_deadend(knot, edge, near, far, d, perp) if edge2.nil?

        far2 = edge2.other(far)
        d2 = far.direction_to(far2)
        perp2 = d2.cross_right

        triangle = Triangle.new(near, far, far2) if d != d2 # the two edges are not colinear

        # midpoints, mid1 == edge1 midpoint, mid2 == edge2 midpoint
        # for impervious edges, the midpoints lie offset from the edges. Otherwise, the
        # midpoints lie on the midpoints themselves.

        if edge.impervious?
          mid1 = edge.midpoint + d.cross_right * 5 # FIXME: don't hard-code the cable width
          outgoing_vector = d
        else
          mid1 = edge.midpoint
          outgoing_vector = d.between(perp).normalize
        end

        if edge2.impervious?
          mid2 = edge2.midpoint + d2.cross_right * 5 # FIXME: don't hard-code the cable width
          incoming_vector = d2.inverse
        else
          mid2 = edge2.midpoint
          incoming_vector = d2.between(perp2).normalize.cross_right
        end

        if triangle && triangle.contains?(mid1 + outgoing_vector*0.01)
          # we're crossing a concave angle
          l1 = Line.new(mid1, mid1 + outgoing_vector)
          l2 = Line.new(mid2, mid2 + incoming_vector)

          pmid = l1.intersect(l2) || mid1.between(mid2)

          curve = Bezier.new([mid1, pmid, pmid, mid2])
          over, under = curve.split(0.5)

          knot.add(edge, over.controls, true)
          knot.add(edge2, under.controls, false)
        else
          # we're crossing a convex angle (outer corner)
          base = mid1.between(mid2) # point between midpoints

          # distance between actual midpoints
          # FIXME: this should probably be a function of the angle between the edges, where
          # a small angle means a large distance (to go around a sharp corner), and a large
          # angle means a small distance.
          if d == d2
            distance = 5
          else
            distance = (edge.midpoint - edge2.midpoint).length
          end

          e2e = mid1.direction_to(mid2).normalize
          meetup = base + e2e.cross_right * distance
          direction = base.direction_to(meetup)

          points = [mid1, mid1 + outgoing_vector * distance * 0.5,
            meetup + direction.cross_right.normalize * distance * 0.5, meetup]
          knot.add(edge, points, true)
          
          points = [meetup, meetup + direction.cross_left.normalize * distance * 0.5,
            mid2 + incoming_vector * distance * 0.5, mid2]
          knot.add(edge2, points, false)
        end

        return [far, edge2]
      end
  end
end
