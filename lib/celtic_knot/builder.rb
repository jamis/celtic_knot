require 'celtic_knot/direction'
require 'celtic_knot/knot'
require 'curves/hermite'

module CelticKnot
  class Builder
    attr_reader :graph, :knot, :state

    def initialize(graph)
      @graph = graph
      @knot = Knot.new
      set_state(:crossings)
    end

    def next_step
      case @state
      when :crossings
        if @thread
          continue_thread
        else
          start_thread
        end
      when :curves
        define_thread
      when :overlap
        compute_overlaps
      when :done
        return nil
      else
        raise "invalid state #{state.inspect}"
      end
    end
        
    private

      def set_state(state)
        @state = state
        @node_i = @edge_j = @thread_i = 0
        @edge = @thread = @connection = @direction = @midpoint = nil
        @stack = []
      end

      def transition_to(state)
        set_state(state)
        return next_step
      end

      def next_edge
        @edge_j += 1

        if @edge_j >= @node.edges.length
          @node_i += 1
          @edge_j = 0
        end
      end

      def start_thread
        loop do
          return transition_to(:curves) if @node_i >= graph.nodes.length

          @node = graph.nodes[@node_i]
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
            @step = 0

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
        @step += 1

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
        difference = 1.0 if difference == 0.0

puts "%d: %s %s" % [@step, @node, @edge]
puts "   far edge:   %s" % far_edge
puts "   parallel:   %s" % parallel
puts "   vector:     %s" % vector
puts "   midpoint:   %s" % @midpoint
puts "   direction:  %s" % @direction
puts "   difference: %f" % difference
        @thread.add_connection(@midpoint, vector, 4.5 * difference, @edge.normal?)

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
        @connection = @connection[:next]

        if @connection == thread.head
          @thread_i += 1
          @connection = thread && thread.head
        end
      end

      def thread
        knot.threads[@thread_i]
      end

      def define_thread
        return transition_to(:overlap) if thread.nil?

        @connection ||= thread.head

        near = @connection
        far = @connection[:next]

        near[:curve] = Curves::Hermite.new([near[:at], near[:vector] * near[:magnitude], far[:at], far[:vector] * near[:magnitude]])

        next_connection

        return knot
      end

      def compute_overlaps
        worker = Proc.new do |start, offset|
          c = start
          loop do
            if c[:intersection]
              if c[:offset]
                offset = c[:offset]
              else
                c[:offset] = offset
              end

              offset = -offset

              crosses = knot.overlaps[c[:at]]
              other = crosses[0][:thread] == thread ? crosses[1] : crosses[0]
              worker[other, offset] unless other[:offset]
            end

            c = c[:next]
            break if c == start
          end
        end

        knot.threads.each { |thread| worker[thread.head, 1] }

        return transition_to(:done)
      end
  end
end
