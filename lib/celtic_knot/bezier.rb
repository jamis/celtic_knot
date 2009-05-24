require 'celtic_knot/path'

module CelticKnot
  class Bezier
    attr_reader :controls

    def initialize(controls)
      raise ArgumentError, "too few control points (must have 3 or 4)" if controls.length < 3
      raise ArgumentError, "too many control points (must have 3 or 4)" if controls.length > 4

      @controls = controls
    end

    def split(at)
      n = controls.length - 1
      points = [controls]
      1.upto(n) do |j|
        points[j] = []
        0.upto(n-j) do |i|
          points[j][i] = (points[j-1][i] * (1 - at)) + (points[j-1][i+1] * at)
        end
      end

      left = (0..n).map { |i| points[i][0] }
      right = (0..n).map { |i| points[n-i][i] }

      [Bezier.new(left), Bezier.new(right)]
    end

    # In general, you can't compute an exact offset curve of a Bezier
    # curve in Bezier form (see Chapter 8 of "Computer Aided Geometric Design"
    # by Thomas W. Sederberg); this naive heuristic is only intended to be
    # "good enough" for what the celtic knot code needs, and is not (in general)
    # even close to an actual offset curve.
    def offset(n)
      v1 = (controls[1] - controls[0])
      v2 = v1.normalize.cross_right

      v3 = (controls[-2] - controls[-1])
      v4 = v3.normalize.cross_left

      p0 = controls[0] + v2 * n
      pn = controls[-1] + v4 * n

      if quadratic?
        v3 = ((v1 + v2) / 2).normalize
        return Bezier.new([p0, controls[1] + v3 * n * 1.2, pn])
      else
        p1 = p0 + v1.normalize * (v1.length + n * 1.2)
        p2 = pn + v3.normalize * (v3.length + n * 1.2)
        return Bezier.new([p0, p1, p2, pn])
      end
    end

    def reverse
      Bezier.new(controls.reverse)
    end

    def quadratic?
      controls.length == 3
    end

    def cubic?
      controls.length == 4
    end

    def *(n)
      Bezier.new(controls.map { |c| c * n })
    end

    def +(p)
      Bezier.new(controls.map { |c| c + p })
    end

    def fat(width)
      outer = offset(width/2.0)
      inner = offset(-width/2.0).reverse
      path = Path.new(outer, inner)
    end

    def inspect
      "bezier(#{controls.join(", ")})"
    end

    def to_svg_path(options={})
      path = "M #{controls.first.x} #{controls.first.y} "
      path << (quadratic? ? "Q" : "C")
      controls[1..-1].each { |p| path << " #{p.x} #{p.y}" }
      path
    end

    def to_svg(options={})
      svg = '<path d="' << to_svg_path(options) << '"'
      options.each { |k,v| svg << " #{k}=\"#{v}\"" }
      svg << " />"
    end
  end
end
