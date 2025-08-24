#!/usr/bin/env ruby

# Shared

require 'pathname'
require 'date'
require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/numeric/time'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
root = cwd.join("..")
args = ARGV

t = Time.now

def uuid
  `uuidgen`.strip
end

def post_slug(date, title)
  slug = [date.strftime("%Y"),date.strftime("%m"),date.strftime("%d")]
  slug = slug + title.downcase.split(" ")
  slug.join("-")
end

def format_date_for_post(date)
  slug = [date.strftime("%Y"),date.strftime("%m"),date.strftime("%d")]
  slug.join("-")
end

# Script

dates = %w[
2025-09-08
2025-10-20
2025-11-03
2025-12-08
2026-01-12
2026-02-02
2026-03-09
2026-04-20
2026-05-11
].map{ |d| Date.parse(d) }

service_dens = [
  "Arrow of Light",
  "Webelos",
  "Bear",
  "Wolf",
  "Tiger",
  "Lion"
]

template = <<-END
---
layout: post
title:  {{title}}
date:   {{post_date}}
featured_image: packmeeting.jpg
tags: [Meetings]
uuid: {{uuid}}
meta:
  date: {{meeting_date}}
  time: 6:30 PM
  location: HSS Library
  service_den: {{service_den}}
---

Scouts at HSS can wear Class A uniforms to school on pack meeting days!
END

dates.each_with_index do |meeting_date, i|
  post_date = i == 0 ? t.to_date : (dates[i-1] + 1.day)
  title = "#{meeting_date.strftime("%B")} Pack Meeting"
  slug = post_slug(post_date, title)
  service_den = service_dens[i%service_dens.length]
  
  puts post = template.sub("{{title}}", title).sub("{{uuid}}", uuid).sub("{{service_den}}", service_den).sub("{{post_date}}", format_date_for_post(post_date)).sub("{{meeting_date}}", format_date_for_post(meeting_date))

  filename = root.join("_posts/#{slug}.md")
  filename.write(post)
end