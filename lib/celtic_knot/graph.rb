require 'strscan'

require 'celtic_knot/edge'
require 'celtic_knot/node'

module CelticKnot
  class Graph
    def self.parse(io)
      nodes = {}

      io.each_line do |line|
        line = line.sub(/#.*$/, "").strip
        next if line.empty?

        if line =~ /^\s*(\w+)\s*:\s*(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)\s*$/
          name = $1.downcase
          x = $2.to_f
          y = $3.to_f
          nodes[name] = Node.new(x,y)
        else
          scanner = StringScanner.new(line.strip)
          near = scanner.scan(/\w+/) or abort "expected node id on #{line.inspect}"
          p1 = nodes[near.downcase] or abort "unknown point #{near.inspect}"

          loop do
            scanner.skip(/\s*/)
            break if scanner.eos?
            type = scanner.scan(/[-,=]/) or abort "expected edge type on #{line.inspect}"
            scanner.skip(/\s*/)
            far = scanner.scan(/\w+/) or abort "expected node id on #{line.inspect}"
            p2 = nodes[far.downcase] or abort "unknown point #{far.inspect}"
            Edge.class_for(type).new(p1, p2)
            p1 = p2
          end
        end
      end

      new(nodes.values)
    end

    attr_reader :nodes

    def initialize(nodes)
      @nodes = nodes
    end
  end
end
