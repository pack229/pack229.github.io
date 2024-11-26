#!/usr/bin/env ruby

require 'icalendar'
require 'icalendar/tzinfo'
require 'pathname'

require 'kramdown'
require 'kramdown-parser-gfm'
require 'nokogiri'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))

require cwd.join("../_plugins/jekyll_format_meta")
class Meta
  include Jekyll::FormatMeta
end

class PackCalendar
  class Event
    attr_reader :title, :url, :body, :event_start, :event_end, :uuid, :mtime, :file, :head, :location
    def initialize(dir, path, contents, tzid)
      @tzid = tzid
      @file = dir.join(path)

      @valid = true
      parts = contents.split("---")
      @valid = !parts[1].nil?
      if @valid
        @head = YAML.load("---\n" + parts[1].strip + "\n", permitted_classes: [Date])

        url_parts = File.basename(path.to_s, ".md").split("-")
        @url = "https://hsspack229.org/#{url_parts[0..2].join("/")}/#{url_parts[3..-1].join("-")}"

        post_date = Icalendar::Values::DateTime.new(head['date'], tzid: @tzid)
        @url = nil if post_date > Time.now

        body = Kramdown::Document.new(parts[2..-1].join("\n").strip, input: 'GFM').to_html
        meta = Meta.new.format_meta_for_email(@head) || ""

        @body = clean_body(meta + body)

        if loc = @head["meta"]["location"]
          loc = Meta.new.location_map(loc)
          @location = loc
        end

        @title = head["title"]
        @title = "Pack Meeting" if @title.match(" Pack Meeting")

        @uuid = head["uuid"].downcase
        @mtime = dir.join(path).mtime

        date = head["meta"]["date"]
        time = head["meta"]["time"]

        @valid = !(head["calendar"] || "").split(",").include?("skip")
        if @valid

          if date.is_a?(Array) && date.length == 2
            event_start = DateTime.parse(date[0])
            @event_start = Icalendar::Values::DateTime.new(event_start, tzid: @tzid)
            event_end = DateTime.parse(date[1])
            @event_end = Icalendar::Values::DateTime.new(event_end, tzid: @tzid)
            @valid = true
          elsif date.is_a?(Date)
            # TODO time ranges or durations
            event_start = DateTime.parse("#{date} #{time}")
            duration = 60.minutes
            event_end = event_start + duration
            @event_start = Icalendar::Values::DateTime.new(event_start, tzid: @tzid)
            @event_end = Icalendar::Values::DateTime.new(event_end, tzid: @tzid)
          else
            @valid = false
          end

        end
      end
    end
    def valid?
      @valid
    end
    def clean_body(body)
      links = []
      body = Nokogiri::HTML(body)
      body.css("a").each do |tag|
        link = tag.attr("href")
        text = if link == nil or link.match(/mailto\:/)
          tag.inner_text
        else
          link = "https://hsspack229.org#{link}" unless link.match(/^http/)
          num = if pos = links.index(link)
            pos
          else
            links << link
            links.count
          end
          "#{tag.inner_text} [Link ##{num}]"
        end
        tag.after(text)
        tag.remove
      end
      body.css("ul").each do |tag|
        tag.css("li").each do |item|
          tag.after(" * #{item.inner_html}\n")
        end
        tag.remove
      end
      # TODO simple formating for H tags?
      %w[ h1 h2 h3 h4 h5 h6 p span ].each do |t|
        body.css(t).each do |tag|
          tag.after("#{tag.inner_text}\n")
          tag.remove
        end
      end
      # <!--more-->
      body_tag = body.at("body")
      return "" if body_tag.nil?
      body = body_tag.inner_html.gsub(/\n{3,}/, "\n\n").to_s
      body = "#{@url}\n\n#{body}" unless @url.nil?
      if links.any?
        links.each_with_index do |l, i|
          body << "[Link ##{i+1}] #{l}\n\n"
        end
      end
      body
    end
  end

  attr_accessor :cal
  def initialize(cwd)
    @cwd = cwd
    @cal = Icalendar::Calendar.new
    @markdown = []
    cal.x_wr_calname = 'Pack 229'
    @sorted_posts = get_sorted_posts
    check_posts!
    setup_time_zones!
    load_from_posts!
    save_ics!
    save_markdown!
  end
  def setup_time_zones!
    @tzid = "America/Los_Angeles"
    tz = TZInfo::Timezone.get(@tzid)
    timezone = tz.ical_timezone(Time.now)
    @cal.add_timezone(timezone)
  end
  def all_posts
    @all_posts ||= get_all_posts
  end
  def get_all_posts
    posts = @cwd.join("../_posts")
    posts.entries.map do |e|
      Event.new(posts, e, posts.join(e).read, @tzid) unless e.basename.to_s[0] == "."
    end.compact
  end
  def get_sorted_posts
    all_posts.select{ |e| e.valid? }.sort_by{ |e| e.event_start }
  end
  def check_posts!
    # raise "Duplicate UUIDs" if get_all_posts.map(&:uuid).count != get_all_posts.map(&:uuid).uniq.count
    used_uuids = []
    all_posts.each do |p|
      raise "Duplicate UUID for #{p.file}" if used_uuids.include?(p.uuid)
      used_uuids << p.uuid
      raise "Check Date for #{p.file}" if p.head['date'].strftime("%Y-%m-%d") != File.basename(p.file).split("-")[0..2].join("-")
    end
  end
  def load_from_posts!
    current_year = nil
    current_month = nil

    @sorted_posts.each do |post|

      cal.event do |e|
        e.summary = "Pack 229: #{post.title}"
        e.description = post.body
        e.url = post.url unless post.url.nil?
        e.dtstart = post.event_start
        e.dtend   = post.event_end
        e.ip_class = "PUBLIC"
        e.location = post.location if post.location
        e.organizer = Icalendar::Values::CalAddress.new("mailto:contact@hsspack229.org", cn: 'Pack 229')
        e.uid = post.uuid
        e.dtstamp = Icalendar::Values::DateTime.new(post.mtime, tzid: @tzid)
      end

      # Markdown
      if post.event_start.year != current_year
        @markdown << "# #{post.event_start.year}"
        current_year = post.event_start.year
      end
      if post.event_end.month != current_month
        @markdown << "## #{post.event_end.strftime("%B")}"
        current_month = post.event_end.month
      end
      titl = if post.url
        "[#{post.title}](#{post.url})"
      else
        post.title
      end
      @markdown << " * __#{post.event_start.strftime("%a %m/%d")}:__ #{titl}"

    end
  end
  def save_ics!
    @cwd.join("../ics/pack229.ics").write(@cal.to_ical)
  end
  def save_markdown!
    token = "<!-- Generated Calendar -->"
    file = @cwd.join("../calendar.md")
    calendar = file.read.split(token)[0] + token + "\n\n" + @markdown.join("\n\n")
    file.write(calendar)
  end
end

pack = PackCalendar.new(cwd)
