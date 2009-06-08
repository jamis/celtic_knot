require 'celtic_knot/thread'

module CelticKnot
  class Knot
    attr_reader :threads
    attr_reader :overlaps

    def initialize
      @threads = []
      @overlaps = Hash.new { |h,k| h[k] = [] }
    end

    def new_thread
      thread = Thread.new(self)
      @threads << thread
      return thread
    end
  end
end
