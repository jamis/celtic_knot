module CelticKnot
  class KnotShape
    attr_reader :knot
    attr_reader :options
    attr_reader :segments

    def initialize(knot, options={})
      @knot = knot
      @options = options

      @segments = {}

      inflate_threads
      #cull_overlaps
    end

    private

      class ThreadSegment
        attr_reader :left
        attr_reader :right
        attr_reader :connection

        def initialize(connection)
          @connection = connection
          @left = []
          @right = []
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
              p1 = list[i]
              p2 = list[i+1]

              j = i+1
              while j < list.length-1
                p3 = list[j]
                p4 = list[j+1]

                if (intersection = intersection_of(p1, p2, p3, p4))
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

          def intersection_of(p1, p2, p3, p4)
            denom = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y)
            return nil if denom == 0.0

            ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denom
            return nil if ua <= 0.0 || ua >= 1.0

            ub = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denom
            return nil if ub <= 0.0 || ub >= 1.0

            intersection = p1 + (p2 - p1) * ua
            return intersection
          end
      end

      def inflate_threads
        width = options.fetch(:width, 10).to_f
        half_width = width / 2

        knot.threads.each do |thread|
          thread.each_connection do |c|
            segment = ThreadSegment.new(c)

            0.step(1.01, 0.05) do |t|
              point = c[:curve].evaluate(t)
              normal = c[:curve].tangent(t).rotate_ccw.normalize
              offset = normal * half_width

              from_z = c[:offset].to_f
              to_z = c[:next][:offset].to_f

              z = from_z + (to_z - from_z) * t

              segment.left << point + offset
              segment.right << point - offset
            end

            segment.cull_interior_overlaps!
            segments[c] = segment
          end
        end
      end
  end
end
