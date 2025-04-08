#!/usr/bin/env ruby

require 'pathname'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
root = cwd.join("..")
args = ARGV

t = Time.now

date = [t.strftime("%Y"),t.strftime("%m"),t.strftime("%d")]
title = args.join(" ")
args = args.map{ |it| it.downcase }
title_slug = args.join("_")
filename = root.join("_posts/#{(date+args).join("-")}.md")
uuid = `uuidgen`.strip

featured_image = "default.jpg"
featured_image = "packmeeting.jpg" if title.match("Pack Meeting")

contents = <<-END
---
layout: post
title: #{title}
date: #{date.join("-")}
tags: [Events]
uuid: #{uuid}
featured_image: #{featured_image}
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

Scouts at HSS can wear Class A uniforms to school on pack meeting days!

{% include gallery.html folder="2025/#{title_slug}" %}
END

filename.write(contents)
