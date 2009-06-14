require 'curves/line_segment'

module CelticKnot
  class KnotShape
    DEFAULT_WIDTH = 10

    attr_reader :knot
    attr_reader :options
    attr_reader :polygons

    def initialize(knot, options={})
      @knot = knot
      @options = options

      @segments = {}
      @polygons = []

      inflate_threads
      subtract_intersections
      construct_polygons
    end

    def width
      options.fetch(:width, DEFAULT_WIDTH).to_f
    end

    def separation
      [0.0, options.fetch(:separation, 0).to_f].max
    end

    private

      class Polygon
        attr_reader :thread
        attr_reader :points

        def initialize(thread)
          @thread = thread
          @points = []
        end
      end

      class ThreadSegment
        attr_reader :left
        attr_reader :right

        def initialize
          @left = []
          @right = []
        end

        def append(segment)
          if left.last == segment.left.first
            left.pop
            right.pop
          end

          left.concat(segment.left)
          right.concat(segment.right)
          return self
        end

        def cull_interior_overlaps!
          cull_overlap_for_list(left)
          cull_overlap_for_list(right)
        end

        private

          # look for a single self-intersection in list (which will be
          # caused when a thread segment has a tight curve, and is
          # inflated to a point where the inner edge of the inflated
          # curve doubles back on itself). If such a self-intersection
          # exists, remove the intersection by reducing all lines between
          # the intersection to the point of intersection.
          def cull_overlap_for_list(list)
            i = 0
            while i < list.length-2
              line1 = Curves::LineSegment.new(list[i], list[i+1])

              j = i+1
              while j < list.length-1
                line2 = Curves::LineSegment.new(list[j], list[j+1])

                if (intersection = line1.intersection(line2))
                  while i < j
                    i += 1
                    list[i] = intersection
                  end
                  return
                end

                j += 1
              end

              i += 1
            end
          end
      end

      def inflate_threads
        half_width = width / 2

        knot.threads.each do |thread|
          thread.each_connection do |c|
            @segments[c] = inflate_connection(c, half_width, 0.0, 1.0)
          end
        end
      end

      def inflate_connection(c, offset, t0, t1)
        segment = ThreadSegment.new

        t0.step(t1 + 0.01, 0.05) do |t|
          point = c[:curve].evaluate(t)
          normal = c[:curve].tangent(t).rotate_ccw.normalize
          vector = normal * offset

          segment.left << point + vector
          segment.right << point - vector
        end

        segment.cull_interior_overlaps!
        return segment
      end

      def subtract_intersections
        offset = width / 2 + separation

        knot.overlaps.each do |point, list|
          next if list.length < 2
          lower, upper = list[0][:offset] < list[1][:offset] ? list : [list[1], list[0]]

          bounds = inflate_connection(upper[:prev], offset, 0.5, 1.0).
            append(inflate_connection(upper, offset, 0.0, 0.5))

          left = upper[:vector].rotate_ccw

          # if the normal facing left of the direction of the upper thread points in
          # the same direction as the lower thread, then the lower thread intersects
          # with the left side of the inflated upper thread, and lower[:prev]
          # intersections with the right side of the inflated upper thread. If the
          # normal faces the other direction, then the intersections are swapped.

          if left.dot(lower[:vector]) > 0
            subtract_intersection_between(@segments[lower], bounds.left, :start)
            subtract_intersection_between(@segments[lower[:prev]], bounds.right, :end)
          else
            subtract_intersection_between(@segments[lower[:prev]], bounds.left, :end)
            subtract_intersection_between(@segments[lower], bounds.right, :start)
          end
        end
      end

      def subtract_intersection_between(segment, boundary, from)
        operation = from == :start ? :shift : :pop
        reverseop = from == :start ? :unshift : :push

        lp1 = segment.left.send(operation)
        rp1 = segment.right.send(operation)

        found_left = found_right = false

        until found_left && found_right
          unless found_left
            lp2 = segment.left.send(operation)
            lline = Curves::LineSegment.new(lp1, lp2)
          end

          unless found_right
            rp2 = segment.right.send(operation)
            rline = Curves::LineSegment.new(rp1, rp2)
          end
          
          p3 = boundary[0]
          1.upto(boundary.length-1) do |j|
            p4 = boundary[j]
            boundary_line = Curves::LineSegment.new(p3, p4)

            if !found_left && (left_intersection = lline.intersection(boundary_line))
              found_left = j
              segment.left.send(reverseop, lp2)
              segment.left.send(reverseop, left_intersection)
            end

            if !found_right && (right_intersection = rline.intersection(boundary_line))
              found_right = j
              segment.right.send(reverseop, rp2)
              segment.right.send(reverseop, right_intersection)
            end

            break if found_left && found_right
            p3 = p4
          end

          lp1, rp1 = lp2, rp2
        end

        if found_left < found_right
          lo, hi = found_left, found_right
          collection = segment.left
        else
          lo, hi = found_right, found_left
          collection = segment.right
        end

        lo.upto(hi-1) { |j| collection.send(reverseop, boundary[j]) }
      end

      def construct_polygons
        knot.threads.each do |thread|
          thread.each_connection do |c|
            next unless c[:intersection] && c[:offset] < 0
            polygons << build_polygon_for_segments_from(c)
          end
        end
      end

      def build_polygon_for_segments_from(c)
        segment = ThreadSegment.new
        loop do
          segment.append(@segments[c])
          c = c[:next]
          break if c[:offset] && c[:offset] < 0
        end

        polygon = Polygon.new(c[:thread])
        segment.left.each { |pt| polygon.points << pt }
        segment.right.reverse.each { |pt| polygon.points << pt }

        return polygon
      end
  end
end
