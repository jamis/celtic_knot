module CelticKnot
  class Direction
    attr_accessor :opposite

    def initialize(clockwise)
      @clockwise = clockwise
    end

    def cw?
      @clockwise
    end

    def ccw?
      !@clockwise
    end

    def description
      cw? ? "clockwise" : "counter-clockwise"
    end

    def to_s
      description
    end

    def inspect
      "#<#{self.class.name}:#{description}>"
    end

    CW  = new(true)
    CCW = new(false)

    CW.opposite = CCW
    CCW.opposite = CW
  end
end
