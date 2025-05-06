#!/usr/bin/env ruby

require 'pathname'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
root = cwd.join("..")

template = root.join("_slideshow.html").read

slides = []
images = Dir.glob(root.join("images/events/**/*.{jpg}").to_s)

images.each do |i|
  url = "/" + i.split("/")[7..-1].join("/")
  caption = "Caption"
  slides << '<div class="swiper-slide">'
  slides << '  <img src="' + url + '" alt="' + caption + '" />'
  slides << '  <div class="caption">' + caption + '</div>'
  slides << '</div>'
end

template.gsub!("<!--slides-->", slides.join("\n"))
root.join("slideshow.html").write(template)


#
