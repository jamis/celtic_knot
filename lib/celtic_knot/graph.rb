require 'strscan'

require 'celtic_knot/edge'
require 'celtic_knot/node'

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
            Edge.class_for(type).new(p1, p2)
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

      nodes.each do |node|
        if node.edges.empty?
          encircle_node(knot, node)
        else
          node.edges.each do |edge|
            next if edge.marked?(node, Direction::CCW)
            plot_thread(knot, node, edge)
          end
        end
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

      def encircle_node(knot, node)
        # trivial case for a node with no edges. just draw a circle around it.
        raise NotImplementedError
      end

      def plot_thread(knot, near, edge)
        thread = knot.new_thread

        # direction is either "clockwise" or "counter-clockwise",
        # and refers to the direction the cable would travel if it were to
        # orbit the far node, originating at the midpoint of the current
        # edge.

        direction = Direction::CCW

        # mid1 is the "virtual" midpoint of the current edge, as viewed
        # from the given starting node, and travelling in the given direction
        # around the far node.

        mid1 = edge.virtual_midpoint(near, direction, :exit)

n = 0
        loop do
          far = edge.other(near)
          parallel = far - near
          vector = edge.vector(parallel, direction)

          break if thread.closes?(mid1, vector)

n += 1
puts "%d: %s %s | %s %s | %s %s" % [n, near, edge, mid1, vector, parallel, direction]
          thread.add_connection(mid1, vector)

          edge.mark(near, direction)

          edge2 = far.nearest_edge_to(edge, direction) || edge
          mid2 = edge2.virtual_midpoint(far, direction, :enter)

          # if the edge is being ignored, then we reverse direction,
          # keeping all else the same. This has the effect of just
          # passing through the edge.

          if edge2.ignore?
            near = edge2.other(far)
          else
            near = far
            direction = direction.opposite if edge2.normal?
          end

          edge, mid1 = edge2, mid2
        end
      end
  end
end
