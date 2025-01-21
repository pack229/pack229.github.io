#!/usr/bin/env ruby

require 'icalendar'
require 'icalendar/tzinfo'
require 'vcardigan'
require 'pathname'

require 'kramdown'
require 'kramdown-parser-gfm'
require 'nokogiri'

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
$base_url = "https://hsspack229.org"
# $base_url = "http://localhost:4000"

require cwd.join("../_plugins/jekyll_format_meta")
class Meta
  include Jekyll::FormatMeta
end

class PackCalendar

  class Event
    attr_reader :title, :url, :body, :event_start, :event_end, :uuid, :mtime, :file, :head, :location

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
          link = "#{$base_url}#{link}" unless link.match(/^http/)
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
      body_tag = body.at("body")
      return "" if body_tag.nil?
      body = body_tag.inner_html.gsub(/<!--more-->.*$/m, "... [See Website]").to_s.gsub(/<!--.*?-->/, "").to_s.gsub(/\n{3,}/, "\n\n").to_s
      body = "#{@url}\n\n#{body}" unless @url.nil?
      if links.any?
        links.each_with_index do |l, i|
          body << "[Link ##{i+1}] #{l}\n\n"
        end
      end
      body
    end

    def get_post_data

      if @head["meta"] && loc = @head["meta"]["location"]
        loc_data = Meta.new.location_map(loc)
        @location = if loc_data.nil?
          loc
        else
          file_name = "#{loc.downcase.gsub(/[^a-z0-9 ]/, "").gsub(" ", "_")}.vcf"
          card = VCardigan.create
          card.name(loc)
          card.fullname(loc)

          card[:site].label('Site')
          card[:site].url(loc_data[:site])

          card[:map].label('Map')
          card[:map].url(loc_data[:map])

          loc_data[:address]

          @cwd.join("../ics/vcard/#{file_name}").write(card.to_s)
          "ALTREP=\"#{$base_url}/ics/vcard/#{file_name}\": #{loc}"
        end
      end

      @title = head["title"]
      @title = "Pack Meeting" if @title.match(" Pack Meeting")
      @uuid = head["uuid"].downcase
      @mtime = @source_file.mtime

      if @head["meta"]
        date = head["meta"]["date"]
        time = head["meta"]["time"]
      end

      @valid = !(head["calendar"] || "").split(",").include?("skip")
      if @valid
        if date.is_a?(Array) && date.length == 2
          event_start = DateTime.parse(date[0])
          @event_start = Icalendar::Values::DateTime.new(event_start, tzid: @tzid)
          event_end = DateTime.parse(date[1])
          @event_end = Icalendar::Values::DateTime.new(event_end, tzid: @tzid)
          @valid = false # TODO
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

  class PostEvent < Event
    def initialize(cwd, tzid, data, source_file)
      @cwd = cwd
      @tzid = tzid
      @source_file = source_file

      @valid = true

      parts = data.split("---")
      @valid = !parts[1].nil?
      if @valid
        @head = YAML.load("---\n" + parts[1].strip + "\n", permitted_classes: [Date])

        url_parts = File.basename(source_file.to_s, ".md").split("-")
        @url = "#{$base_url}/#{url_parts[0..2].join("/")}/#{url_parts[3..-1].join("-")}"

        post_date = Icalendar::Values::DateTime.new(head['date'], tzid: @tzid)
        @url = nil if post_date > Time.now

        body = Kramdown::Document.new(parts[2..-1].join("\n").strip, input: 'GFM').to_html
        meta = Meta.new.format_meta_for_email(@head) || ""

        @body = clean_body(meta + body)

        get_post_data

      end
    end
  end

  class DenEvent < Event
    def initialize(cwd, tzid, data, source_file)
      @cwd = cwd
      @tzid = tzid
      @source_file = source_file

      @head = data

      @url = nil
      meta = Meta.new.format_meta_for_email(@head) || ""

      @body = clean_body(meta)

      get_post_data

    end
  end

  attr_accessor :cal
  def initialize(cwd, calendar_title)
    @cwd = cwd
    @cal = Icalendar::Calendar.new
    @markdown = []
    cal.x_wr_calname = calendar_title
    @other_posts = []
  end
  def run!
    check_posts!
    setup_time_zones!
    load_from_posts!
  end
  def sorted_posts
    @sorted_posts ||= get_sorted_posts
  end
  def setup_time_zones!
    @tzid = "America/Los_Angeles"
    tz = TZInfo::Timezone.get(@tzid)
    timezone = tz.ical_timezone(Time.now)
    @cal.add_timezone(timezone)
  end
  def all_posts
    @all_posts ||= get_all_posts + @other_posts
  end
  def get_all_posts
    dir = @cwd.join("../_posts")
    dir.entries.map do |path|
      next if path.basename.to_s[0] == "."

      source_file = dir.join(path)
      PostEvent.new(@cwd, @tzid, dir.join(path).read, source_file)
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
      # TODO raise "Check Date for #{p.file}" if p.head['date'].strftime("%Y-%m-%d") != File.basename(p.file).split("-")[0..2].join("-")
    end
  end
  def load_from_posts!
    current_year = nil
    current_month = nil

    sorted_posts.each do |post|

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
  def save_ics!(file_name)
    ical_string = @cal.to_ical
    ical_string.gsub!("LOCATION:ALTREP", "LOCATION;ALTREP")
    @cwd.join("../ics/#{file_name}.ics").write(ical_string)
  end
  def save_markdown!
    token = "<!-- Generated Calendar -->"
    file = @cwd.join("../calendar.md")
    calendar = file.read.split(token)[0] + token + "\n\n" + @markdown.join("\n\n")
    file.write(calendar)
  end
  def load_events!(file)
    source_file = @cwd.join("../_data/calendar_#{file}.yaml")
    data = YAML.load(source_file.read, permitted_classes: [Date])
    data.each do |event|
      @other_posts << DenEvent.new(@cwd, @tzid, event, source_file)
    end
  end
end

pack = PackCalendar.new(cwd, 'Pack 229')
pack.run!
pack.save_ics!("pack229")
pack.save_markdown!

[ "6" ].each do |den_number|
  den = PackCalendar.new(cwd, "Pack 229 & Den #{den_number}")
  den.load_events!("den#{den_number}")
  den.run!
  den.save_ics!("pack229-den#{den_number}")
end
