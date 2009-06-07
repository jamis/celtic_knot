module CelticKnot
  class Thread
    attr_reader :connections

    def initialize
      @connections = []
    end

    def add_connection(point, vector, magnitude)
      connections << { :at => point, :vector => vector, :vnorm => vector.normalize, :magnitude => magnitude }
      self
    end

    def closes?(point, vector)
      connections.first &&
        connections.first[:at] == point &&
        connections.first[:vnorm] == vector.normalize
    end
  end
end
