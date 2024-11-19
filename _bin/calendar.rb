#!/usr/bin/env ruby

require 'icalendar'
require 'icalendar/tzinfo'
require 'pathname'

require 'kramdown'
require 'kramdown-parser-gfm'

class PackCalendar
  attr_accessor :cal, :cwd
  def initialize(cwd)
    @cwd = cwd
    @cal = Icalendar::Calendar.new
    cal.x_wr_calname = 'Pack 229'
    setup_time_zones!
    load_from_posts!
  end
  def setup_time_zones!
    @tzid = "America/Los_Angeles"
    tz = TZInfo::Timezone.get(@tzid)
    timezone = tz.ical_timezone(Time.now)
    cal.add_timezone(timezone)
  end
  def load_from_posts!
    posts = cwd.join("../_posts")
    posts.entries.each do |e|
      unless e.basename.to_s[0] == "."
        path = posts.join(e)
        parts = path.read.split("---")
        head = YAML.load("---\n" + parts[1].strip + "\n", permitted_classes: [Date])
        body = Kramdown::Document.new(parts[2..-1].join("\n").strip, input: 'GFM').to_html

        title = head["title"]

        date = head["meta"]["date"]
        time = head["meta"]["time"]

        next if (head["calendar"] || "").split(",").include?("skip")

        if date.is_a?(Array) && date.length == 2
          # TODO multi day events
        elsif date.is_a?(Date)
          # TODO time ranges or durations
          # TODO time zones

          event_start = DateTime.parse("#{date} #{time}")
          duration = 60.minutes
          event_end = event_start + duration
          cal.event do |e|
            e.summary     = title
            e.description = "Details"
            e.dtstart = Icalendar::Values::DateTime.new(event_start, tzid: @tzid)
            e.dtend   = Icalendar::Values::DateTime.new(event_end, tzid: @tzid)
            e.ip_class = "PUBLIC"
            # e.url = 'https://hsspack229.org/2024/11/06/december-pack-meeting/'
            e.organizer = Icalendar::Values::CalAddress.new("mailto:contact@hsspack229.org", cn: 'Pack 229')
            e.uid = head["uuid"].downcase
            e.dtstamp = Icalendar::Values::DateTime.new(path.mtime, tzid: @tzid)
          end

        else
          # puts "Skipping: #{title}"
        end

      end
    end
  end
  def add_standard_event

  end
end

$cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
pack = PackCalendar.new($cwd)
$cwd.join("../ics/pack229.ics").write(pack.cal.to_ical)
