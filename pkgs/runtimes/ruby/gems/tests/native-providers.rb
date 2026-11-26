require 'pg'
require 'rmagick'
require 'nokogiri'

abort "Wrong PostgreSQL client: #{PG.library_version}" unless PG.library_version == 110009

image = Magick::Image.new(2, 3)
image.pixel_color(0, 0, 'red')
%w[PNG JPEG].each do |format|
  image.format = format
  decoded = Magick::Image.from_blob(image.to_blob).fetch(0)
  unless decoded.format == format && decoded.columns == 2 && decoded.rows == 3
    abort "ImageMagick #{format} roundtrip failed"
  end
  decoded.destroy!
end
image.destroy!

svg = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" width="2" height="3">
    <rect width="2" height="3" fill="red"/>
  </svg>
SVG
raster = Magick::Image.from_blob(svg).fetch(0)
abort 'SVG rasterization dimensions differ' unless raster.columns == 2 && raster.rows == 3
pixel = raster.pixel_color(0, 0)
abort 'SVG rectangle was not rendered' unless pixel.red > pixel.green && pixel.red > pixel.blue
raster.format = 'PNG'
abort 'SVG to PNG conversion failed' unless raster.to_blob.start_with?("\x89PNG\r\n\x1a\n".b)
raster.destroy!

xml_versions = Nokogiri::VERSION_INFO.fetch('libxml')
unless xml_versions.fetch('compiled') == xml_versions.fetch('loaded')
  abort "Compiled and loaded libxml2 versions differ: #{xml_versions}"
end
document = Nokogiri::XML('<answer>42</answer>')
abort 'XML parsing failed' unless document.at_xpath('/answer').text == '42'
stylesheet = Nokogiri::XSLT(<<~XML)
  <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:template match="/"><result><xsl:value-of select="answer"/></result></xsl:template>
  </xsl:stylesheet>
XML
transformed = stylesheet.transform(document)
abort 'XSLT transformation failed' unless transformed.at_xpath('/result').text == '42'

print 'native-providers-ok'
