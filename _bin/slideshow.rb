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

  slide = [ '<div class="swiper-slide">' ]
  slide << '  <img src="' + url + '" alt="' + (caption || "Image") + '" />'
  slide << '  <div class="caption">' + caption + '</div>' if caption
  slide << '</div>'
  slides << slide
end

slides = slides.shuffle

template.gsub!("<!--slides-->", slides.flatten.join("\n"))
root.join("slideshow.html").write(template)


#
