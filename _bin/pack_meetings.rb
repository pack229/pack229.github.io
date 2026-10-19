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
  2026-11-2
  2026-12-7
  2027-1-25
  2027-2-8
  2027-3-8
  2027-4-19
  2027-5-17
].map{ |d| Date.parse(d) }

service_dens = [
  "Wolf",
  "Tiger",
  "Lion",
  "Wolf",
  "Arrow of Light",
  "Tiger",
  "Bear"
]

topics = [
  "Decorating Ornaments for Christmas in the Park",
  "Holiday Party",
  "Pinewood Derby Car Distrobution",
  "Pinewood Derby Prep",
  "Bridging",
  "Camping Prep",
  "Advancement"
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

Topic: {{topic}}

Scouts at HSS can wear Class A uniforms to school on pack meeting days!
END

dates.each_with_index do |meeting_date, i|
  post_date = i == 0 ? t.to_date : (dates[i-1] + 1.day)
  title = "#{meeting_date.strftime("%B")} Pack Meeting"
  slug = post_slug(post_date, title)
  service_den = service_dens[i%service_dens.length]
  topic = topics[i%topics.length]
  
  puts post = template.sub("{{title}}", title).sub("{{topic}}", topic).sub("{{uuid}}", uuid).sub("{{service_den}}", service_den).sub("{{post_date}}", format_date_for_post(post_date)).sub("{{meeting_date}}", format_date_for_post(meeting_date))

  filename = root.join("_posts/#{slug}.md")
  filename.write(post)
end