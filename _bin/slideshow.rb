#!/usr/bin/env ruby

require 'pathname'
require 'fileutils'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
root = cwd.join("..")

template = root.join("_slideshow.html").read

slides = []
images = Dir.glob(root.join("images/events/**/*.{jpg}").to_s)

images.each do |i|
  url = "/" + i.split("/")[7..-1].join("/")

  cf1 = "/" + i.split("/")[1..-2].join("/") + "/caption.txt"
  caption = if File.exist?(cf1)
    c = Pathname.new(cf1).read.strip
    c = nil if c == ""
    c
  else
    FileUtils::Verbose.touch(cf1)
    nil
  end

  slides << '<div class="swiper-slide">'
  slides << '  <img src="' + url + '" alt="' + (caption || "Image") + '" />'
  slides << '  <div class="caption">' + caption + '</div>' if caption
  slides << '</div>'
end

template.gsub!("<!--slides-->", slides.join("\n"))
root.join("slideshow.html").write(template)


#
