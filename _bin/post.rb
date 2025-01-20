#!/usr/bin/env ruby

require 'pathname'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
root = cwd.join("..")
args = ARGV

date = [args.shift,args.shift,args.shift]
title = args.join(" ")
args = args.map{ |it| it.downcase }
filename = root.join("_posts/#{(date+args).join("-")}.md")
uuid = `uuidgen`.strip

contents = <<-END
---
layout: post
title: #{title}
date: #{date.join("-")}
tags: [Events]
uuid: #{uuid}
featured_image: default.jpg
meta:
  date:
    - 2024-10-25 5:00 PM
    - 2024-10-26 5:00 PM
  location:
  signup:
    - title: Event Signup
      url: https://
    - title: Pack Signup
      url: https://
  cost:
  deadline:
  more_info:
---

CONTENT
END

filename.write(contents)
