module CelticKnot
  class Thread
    attr_reader :knot
    attr_reader :head
    attr_reader :tail

    def initialize(knot)
      @knot = knot
      @head = @tail = nil
    end

    def each_connection
      c = head
      loop do
        yield c
        c = c[:next]
        break if c == head
      end
      self
    end

    def add_connection(point, vector, magnitude, intersection)
      connection = { :at           => point,
                     :vector       => vector,
                     :magnitude    => magnitude,
                     :thread       => self,
                     :intersection => intersection }

      knot.overlaps[point] << connection

      @head ||= connection
      @tail ||= connection

      @tail[:next] = connection
      @head[:prev] = connection

      connection[:prev] = @tail
      connection[:next] = @head

      @tail = connection

      self
    end

    def closes?(point, vector)
      head && head[:at] == point && head[:vector] == vector.normalize
    end
  end
end
