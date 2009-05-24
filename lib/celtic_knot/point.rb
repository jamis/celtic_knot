module CelticKnot
  class Point
    DELTA = 0.00001

    def self.[](x,y)
      new(x,y)
    end

    attr_reader :x, :y

    def initialize(x,y)
      @x, @y = x, y
    end

    def ==(p)
      (p.x - x).abs <= DELTA && (p.y - y).abs <= DELTA
    end

    def *(n)
      Point[x*n, y*n]
    end

    def +(p)
      Point[x+p.x, y+p.y]
    end

    def -(p)
      Point[x-p.x, y-p.y]
    end

    def /(n)
      Point[x/n, y/n]
    end

    def dot(v)
      x * v.x + y * v.y
    end

    def length
      @length ||= Math.sqrt(x*x + y*y)
    end

    def inverse
      Point[-x, -y]
    end

    def normalize
      Point[x/length, y/length]
    end

    def direction_to(p)
      (p - self).normalize
    end

    def between(p)
      (self + p) / 2
    end

    def cross_left
      Point[-y, x]
    end

    def cross_right
      Point[y, -x]
    end

    # The length of the cross product of this vector with the argument
    def xlength(v)
      x * v.y - y * v.x
    end

    # The angle between this vector and the argument. If the vectors are
    # the same, the angle will be zero. If the vectors are opposite, the
    # angle will be pi. Clockwise angles are positive (up to pi), and
    # counter-clockwise angles are negative (down to -pi).
    def angle(v)
      Math.atan2(xlength(v), dot(v))
    end

    def to_s
      "(#{x},#{y})"
    end

    def inspect
      to_s
    end
  end
end
