require 'celtic_knot/thread'
require 'celtic_knot/direction'
require 'celtic_knot/knot_shape'
require 'curves/hermite'

module CelticKnot
  class Knot
    attr_reader :graph
    attr_reader :threads
    attr_reader :overlaps
    attr_reader :options

    def initialize(graph, options={})
      @graph = graph
      @threads = []
      @overlaps = Hash.new { |h,k| h[k] = [] }
      @options = options
      generate!
    end

    def draw(draw_options={})
      KnotShape.new(self, options.merge(draw_options))
    end

    private

      def generate!
        compute_crossings
        compute_overlaps
        define_threads
        # smooth_threads
      end

      def compute_crossings
        graph.nodes.each do |node|
          if node.edges.empty?
            # FIXME: implement this case
            new_singularity(node)
          else
            node.edges.each do |edge|
              next if edge.marked?(node, Direction::CCW)
              follow_thread_from(node, edge)
            end
          end
        end
      end

      def follow_thread_from(node, edge)
        thread = Thread.new(self)
        threads << thread

        direction = Direction::CCW
        midpoint = edge.virtual_midpoint(node, direction, :start)

        step = 0

        loop do
          step += 1

          far = edge.other(node)
          parallel = far - node
          vector = edge.vector(parallel, direction)

          break if thread.closes?(midpoint, vector)

          far_edge = far.nearest_edge_to(edge, direction)
          far_midpoint = far_edge.virtual_midpoint(far, direction, :enter)

          if far_edge == edge
            difference = 1.0
          else
            difference = edge.difference(far_edge, direction)
            difference = 1.0 if difference == 0.0
          end

          distance = ((far - midpoint).length + (far - far_midpoint).length)
          magnitude = Math::PI * distance * difference

          if $DEBUG
            puts "%d: %s %s" % [step, node, edge]
            puts "   far edge:   %s" % far_edge
            puts "   parallel:   %s" % parallel
            puts "   vector:     %s" % vector
            puts "   midpoint:   %s" % midpoint
            puts "   direction:  %s" % direction
            puts "   difference: %f" % difference
            puts "   distance:   %f" % distance
            puts "   magnitude:  %f" % magnitude
          end

          thread.add_connection(midpoint, vector.normalize, magnitude, edge.normal?)
          edge.mark(node, direction)

          edge, midpoint = far_edge, far_midpoint

          # if the edge is being ignored, then we reverse direction,
          # keeping all else the same. This has the effect of just
          # passing through the edge.

          if edge.ignore?
            node = edge.other(far)
          else
            node = far
            direction = direction.opposite if edge.normal?
          end
        end
      end

      def define_threads
        threads.each { |thread| define_thread(thread) }
      end

      def define_thread(thread)
        near = thread.head
        loop do
          far = near[:next]

          near[:curve] = Curves::Hermite.new([near[:at], near[:vector] * near[:magnitude], far[:at], far[:vector] * near[:magnitude]])

          near = far
          break if near == thread.head
        end
      end

      def compute_overlaps
        threads.each { |thread| compute_overlaps_for(thread.head) }
      end

      def compute_overlaps_for(start, offset=1)
        c = start
        loop do
          if c[:intersection]
            if c[:offset]
              offset = c[:offset]
            else
              c[:offset] = offset
            end

            offset = -offset

            crosses = overlaps[c[:at]]
            other = crosses[0][:thread] == start[:thread] ? crosses[1] : crosses[0]
            compute_overlaps_for(other, offset) unless other[:offset]
          end

          c = c[:next]
          break if c.object_id == start.object_id
        end
      end
  end
end
