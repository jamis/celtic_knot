require 'celtic_knot/direction'
require 'celtic_knot/knot'
require 'curves/hermite'

module CelticKnot
  class Builder
    attr_reader :graph, :knot

    def initialize(graph)
      @graph = graph
      @knot = Knot.new
      @node_i = @edge_j = @thread_i = @connection_j = 0
      @edge = @thread = @direction = @midpoint = nil
      @step = 0
    end

    def next_step
      @step += 1
      if @node_i < graph.nodes.length
        if @thread
          continue_thread
        else
          start_thread
        end
      elsif @thread_i < knot.threads.length
        @thread = knot.threads[@thread_i]
        define_thread
      end
    end
        
    private

      def next_edge
        @edge_j += 1

        if @edge_j >= @node.edges.length
          @node_i += 1
          @edge_j = 0
        end
      end

      def start_thread
        loop do
          @node = graph.nodes[@node_i] or return nil
          @edge = @node.edges[@edge_j]

          if @edge.nil?
            knot.new_singularity(@node)
            next_edge
            return knot

          elsif @edge.marked?(@node, Direction::CCW)
            next_edge

          else
puts "thread ------>"
            @thread = knot.new_thread

            # direction is either "clockwise" or "counter-clockwise",
            # and refers to the direction the cable would travel if it were to
            # orbit the far node, originating at the midpoint of the current
            # edge.

            @direction = Direction::CCW

            # midpoint is the "virtual" midpoint of the current edge, as viewed
            # from the given starting node, and travelling in the given direction
            # around the far node.

            @midpoint = @edge.virtual_midpoint(@node, @direction, :start)

            return continue_thread
          end
        end
      end

      def continue_thread
        far = @edge.other(@node)
        parallel = far - @node
        vector = @edge.vector(parallel, @direction)

        if @thread.closes?(@midpoint, vector)
          @thread = nil
          next_edge
          return start_thread
        end

        far_edge = far.nearest_edge_to(@edge, @direction)
        difference = @edge.difference(far_edge, @direction)

puts "%d: %s %s" % [@step, @node, @edge]
puts "   far edge:   %s" % far_edge
puts "   parallel:   %s" % parallel
puts "   vector:     %s" % vector
puts "   midpoint:   %s" % @midpoint
puts "   direction:  %s" % @direction
puts "   difference: %f" % difference
        @thread.add_connection(@midpoint, vector, 4.5 * difference)

        @edge.mark(@node, @direction)

        @edge = far_edge
        @midpoint = @edge.virtual_midpoint(far, @direction, :enter)

        # if the edge is being ignored, then we reverse direction,
        # keeping all else the same. This has the effect of just
        # passing through the edge.

        if @edge.ignore?
          @node = @edge.other(far)
        else
          @node = far
          @direction = @direction.opposite if @edge.normal?
        end

        return knot
      end

      def next_connection
        @connection_j += 1

        if @connection_j >= @thread.connections.length
          @connection_j = 0
          @thread_i += 1
        end
      end

      def define_thread
        near = @thread.connections[@connection_j]
        far = @thread.connections[(@connection_j + 1) % @thread.connections.length]
        near[:curve] = Curves::Hermite.new([near[:at], near[:vector] * near[:magnitude], far[:at], far[:vector] * near[:magnitude]])
        next_connection
        return knot
      end
  end
end
