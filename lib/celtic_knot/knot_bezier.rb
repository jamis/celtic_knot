require 'celtic_knot/bezier'

module CelticKnot
  class KnotBezier < Bezier
    attr_reader :over

    def initialize(controls, over)
      super(controls)
      @over = over
    end
  end
end
