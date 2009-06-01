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
        edge2 = far.edges_without(edge).first
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

        mid1 = edge.virtual_midpoint(near, :outgoing)
        mid2 = edge2.virtual_midpoint(far, :incoming)

        outgoing_vector = edge.vector(d, :outgoing)
        incoming_vector = edge2.vector(d2, :incoming)

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

          # distance from the base to where the two curve segments will meet
          # FIXME: for best results, this should probably take into account the tangents
          # at each midpoint; otherwise, loops that circle a single node (due to ignored
          # edges) will be very flat on one side.

          midpoint_separation = (mid1 - mid2).length
          max_separation = (far - mid1).length + (mid2 - far).length
          ratio = (midpoint_separation / max_separation) ** 2
          distance = (max_separation - 5) * (1 - ratio) + 5 # FIXME: don't hard-code cable width

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
