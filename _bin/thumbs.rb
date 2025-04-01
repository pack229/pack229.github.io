#!/usr/bin/env ruby

require 'pathname'
require 'fileutils'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
base = cwd.join("..")

events = base.join("images/events")
thumbs = base.join("images/thumbs")

FileUtils::Verbose.rm_rf(thumbs)

events.each_child do |y|
  if y.directory?
    y.each_child do |e|
      if e.directory?
        short_name = e.to_s[events.to_s.length..-1]
        thumb_d = "#{thumbs}#{short_name}"
        FileUtils::Verbose.mkdir_p(thumb_d)
        cmd = "cd #{e} && sips -Z 880 *.jpg --out #{thumb_d}"
        puts cmd
        puts `#{cmd}`
      end
    end
  end
end


