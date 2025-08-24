#!/usr/bin/env ruby

require 'pathname'
require 'fileutils'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
base = cwd.join("..")

events = base.join("images/events")
thumbs = base.join("images/thumbs")

FileUtils::Verbose.rm_rf(thumbs)

def cmd(c)
  # puts c
  result = `#{c}`
  # puts result
  result
end

# Galleries

# events.each_child do |y|
#   if y.directory?
#     y.each_child do |e|
#       if e.directory?
#         short_name = e.to_s[events.to_s.length..-1]
#         thumb_d = "#{thumbs}#{short_name}"
#         FileUtils::Verbose.mkdir_p(thumb_d)
#         cmd "cd #{e} && sips -Z 880 *.jpg --out #{thumb_d}"
#       end
#     end
#   end
# end

# Posts for OG Images

posts = base.join("images/posts")
posts_cropped = base.join("images/posts-cropped")
posts.each_child do |y|
  next if y.basename.to_s[0] == "."
  width = cmd("cd #{posts} && sips -g pixelWidth #{y}").match(/pixelWidth: (\d+)/).captures.first.to_i
  height = cmd("cd #{posts} && sips -g pixelHeight #{y}").match(/pixelHeight: (\d+)/).captures.first.to_i
  crop_width = (height.to_f * 1.91).round.to_i
  cmd "cd #{posts} && sips -c #{height} #{crop_width} #{y.basename} --cropOffset 0 0 --out #{posts_cropped}"
end