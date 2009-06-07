require 'celtic_knot/thread'

module CelticKnot
  class Knot
    attr_reader :threads

    def initialize
      @threads = []
    end

    def new_thread
      thread = Thread.new
      @threads << thread
      return thread
    end

    def to_svg(options={})
      svg = "<g>\n"

      options = options.dup
      width = options.delete(:width) || 2
      fill_color = options.delete(:fill) || "white"
      stroke_color = options.delete(:stroke) || "black"

      stroke_opts = { :stroke => stroke_color, 'stroke-width' => width, :fill => "none" }.merge(options)
      fill_opts = { :stroke => fill_color, 'stroke-width' => width-1, :fill => "none" }.merge(options)

      curves.select { |c| !c.over }.each do |curve|
        svg << curve.to_svg(stroke_opts) << "\n"
        svg << curve.to_svg(fill_opts) << "\n"
      end

      curves.select { |c| c.over }.each do |curve|
        svg << curve.to_svg(stroke_opts) << "\n"
        svg << curve.to_svg(fill_opts) << "\n"
      end

      @marks.each do |id, pt|
        svg << '<circle cx="%f" cy="%f" r="1" fill="red" stroke="red" id="%s" />' % [pt.x, pt.y, id]
      end

      svg << "</g>\n"
    end
  end
end
