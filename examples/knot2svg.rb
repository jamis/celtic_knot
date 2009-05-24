$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'celtic_knot'

knot_file = ARGV.first or abort "please specify the knot file to read"

graph = File.open(knot_file) { |file| CelticKnot::Graph.parse(file) }
knot = graph.construct_knot

basename = File.basename(knot_file, ".knot")
svg_file = basename + ".svg"

File.open(svg_file, "w") do |svg|
  svg.puts '<?xml version="1.0" standalone="no"?>'
  svg.puts '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">'
  svg.puts '<svg width="5cm" height="5cm" version="1.1" xmlns="http://www.w3.org/2000/svg">'

  # uncomment this line to include the original graph in the output
  # svg.puts graph.to_svg(:color => "#fcc")

  svg.puts knot.to_svg(:width => 5, :fill => "#77f", :stroke => "#007")
  svg.puts '</svg>'
end

puts "knot written to #{svg_file}"
