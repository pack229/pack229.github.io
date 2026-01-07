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

posts_dir = cwd.join("../_posts")
posts = posts_dir.children.map{ |c| c.basename.to_s }.sort.reverse
term = ARGV.join("-")
post_names = posts.select{ |p| p.match(term) }

post_names.each_with_index do |post, i|
  puts "#{i+1}: #{post}"
end
choice = STDIN.gets.chomp.to_i
post_name = post_names[choice-1]

raise "No Post Found" if post_name.nil?
puts "Found: #{post_name}"

template = posts_dir.join(post_name).read

date = format_date_for_post(t)
template.sub!(/date:\s.*?\n/, "date: #{date}\n")
template.sub!(/uuid:\s.*?\n/, "uuid: #{uuid}\n")

new_filename = date + "-" + post_name.split("-")[3..-1].join("-")
puts "New File: #{new_filename}"

posts_dir.join(new_filename).write(template)