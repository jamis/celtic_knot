module CelticKnot
  class Triangle
    attr_reader :a, :b, :c

    def initialize(a, b, c)
      @a, @b, @c = a, b, c
    end

    def centroid
      @centroid ||= (a + b + c) / 3.0
    end

    def contains?(p)
      v0 = c - a
      v1 = b - a
      v2 = p - a

      dot00 = v0.dot(v0)
      dot01 = v0.dot(v1)
      dot02 = v0.dot(v2)
      dot11 = v1.dot(v1)
      dot12 = v1.dot(v2)

      inv = 1 / (dot00 * dot11 - dot01 * dot01)
      u = (dot11 * dot02 - dot01 * dot12) * inv
      v = (dot00 * dot12 - dot01 * dot02) * inv

      return (u > 0) && (v > 0) && (u + v < 1)
    end
  end
end
