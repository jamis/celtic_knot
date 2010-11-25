require 'celtic_knot/thread'
require 'celtic_knot/direction'
require 'celtic_knot/knot_shape'
require 'curves/hermite'

require 'benchmark'

module CelticKnot
  class Knot
    # threads that span angles more than 210 degrees will, when split
    # at their apex, be sufficiently far from the node to look
    # okay. This is because 210 degrees gives the apex a distance from
    # the pivot node equal to half the distance from the pivot node to
    # the edge midpoints, which is also how far (on average) the pivot
    # node is from the midpoint of the line between the two edge
    # midpoints.
    OBTUSE_THRESHOLD = 0.583 # 58.3% of 360 degrees == 210 degrees

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
      time("draw") { KnotShape.new(self, options.merge(draw_options)) }
    end

    private

      def time(operation)
        result = nil
        duration = Benchmark.realtime { result = yield }
        puts "[%s] %.2gs" % [operation, duration]
        return result
      end

      def generate!
        time("compute_crossings") { compute_crossings }
        time("compute_overlaps")  { compute_overlaps }
        time("define_threads")    { define_threads }
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

        loop do
          far = edge.other(node)
          parallel = far - node
          vector = edge.vector(parallel, direction)

          break if thread.closes?(midpoint, vector)

          far_edge = far.nearest_edge_to(edge, direction)
          far_midpoint = far_edge.virtual_midpoint(far, direction, :enter)

          if far_edge == edge
            arc = 1.0
          else
            arc = edge.difference(far_edge, direction)
            arc = 1.0 if arc == 0.0
          end

          distance = (far - midpoint).length + (far - far_midpoint).length

          if obtuse?(arc)
            # split into two thread segments
            nadir = midpoint + ((far_midpoint - midpoint) / 2)
            horizon_vector = far - nadir

            # FIXME FIXME
            # distance of apex from nadir needs to be a function of arc, and the
            # connection weight needs to be a function of something more sophisticated
            # than just the circumference of a circle...maybe include horizon_vector?

            apex = nadir + horizon_vector * 1.5
            thread.add_connection(:at => midpoint, :vector => vector.normalize,
              :arc => arc/2, :weight => Math::PI * arc/4 * distance,
              :intersection => edge.normal?)

            apex_direction = horizon_vector.rotate_cw.normalize
            apex_direction = apex_direction.inverse if apex_direction.dot(vector) < 0

            thread.add_connection(:at => apex, :vector => apex_direction,
              :arc => arc/2, :weight => Math::PI * arc/4 * distance, :intersection => false)
          else
            # create a single thread segment between the two midpoints
            thread.add_connection(:at => midpoint, :vector => vector.normalize,
              :arc => arc,
              :weight => Math::PI * arc * distance, :intersection => edge.normal?)
          end

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

          near_vector = best_vector_for(near) * near[:weight]
          far_vector  = best_vector_for(far) * near[:weight]

          near[:curve] = Curves::Hermite.new([near[:at], near_vector, far[:at], far_vector])

          near = far
          break if near == thread.head
        end
      end

      def best_vector_for(connection)
        connection[:best_vector] ||= begin
          prev_at = connection[:prev][:arc] >= 0.5 ? connection[:at] : connection[:prev][:at]
          next_at = connection[:arc] >= 0.5 ? connection[:at] : connection[:next][:at]

          next_at == prev_at ? connection[:vector] : (next_at - prev_at).normalize
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

      def obtuse?(arc)
        arc > OBTUSE_THRESHOLD
      end
  end
end
