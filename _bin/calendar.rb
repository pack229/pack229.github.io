#!/usr/bin/env ruby

require 'icalendar'
require 'icalendar/tzinfo'
require 'pathname'

require 'kramdown'
require 'kramdown-parser-gfm'
require 'nokogiri'

class PackCalendar
  attr_accessor :cal
  def initialize(cwd)
    @cwd = cwd
    @cal = Icalendar::Calendar.new
    @markdown = []
    cal.x_wr_calname = 'Pack 229'
    setup_time_zones!
    load_from_posts!
    save_ics!
    save_markdown!
  end
  def setup_time_zones!
    @tzid = "America/Los_Angeles"
    tz = TZInfo::Timezone.get(@tzid)
    timezone = tz.ical_timezone(Time.now)
    cal.add_timezone(timezone)
  end
  def load_from_posts!
    current_year = nil
    current_month = nil

    posts = @cwd.join("../_posts")
    posts.entries.each do |e|
      unless e.basename.to_s[0] == "."
        path = posts.join(e)
        parts = path.read.split("---")
        next if parts[1].nil?
        head = YAML.load("---\n" + parts[1].strip + "\n", permitted_classes: [Date])
        body = Kramdown::Document.new(parts[2..-1].join("\n").strip, input: 'GFM').to_html

        url_parts = File.basename(e.to_s, ".md").split("-")
        url = "https://hsspack229.org/#{url_parts[0..2].join("/")}/#{url_parts[3..-1].join("-")}"

        body = Nokogiri::HTML(body)
        body.css("a").each do |tag|
          link = tag.attr("href")
          text = if link == nil or link.match(/mailto\:/)
            tag.inner_text
          else
            link = "https://hsspack229.org#{link}" unless link.match(/^http/)
            "#{tag.inner_text} (#{link})"
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
        body = body.at("body").inner_html.gsub(/\n{3,}/, "\n\n").to_s
        body = "#{url}\n\n#{body}" unless url.nil?

        title = head["title"]
        date = head["meta"]["date"]
        time = head["meta"]["time"]

        next if (head["calendar"] || "").split(",").include?("skip")
        title = "Pack Meeting" if title.match(" Pack Meeting")

        if date.is_a?(Array) && date.length == 2
          # TODO multi day events
        elsif date.is_a?(Date)
          # TODO time ranges or durations
          # TODO time zones

          event_start = DateTime.parse("#{date} #{time}")
          duration = 60.minutes
          event_end = event_start + duration
          evnt = cal.event do |e|
            e.summary = "Pack 229: #{title}"
            e.description = body
            e.url = url unless url.nil?
            e.dtstart = Icalendar::Values::DateTime.new(event_start, tzid: @tzid)
            e.dtend   = Icalendar::Values::DateTime.new(event_end, tzid: @tzid)
            e.ip_class = "PUBLIC"
            # e.url = 'https://hsspack229.org/2024/11/06/december-pack-meeting/'
            e.organizer = Icalendar::Values::CalAddress.new("mailto:contact@hsspack229.org", cn: 'Pack 229')
            e.uid = head["uuid"].downcase
            e.dtstamp = Icalendar::Values::DateTime.new(path.mtime, tzid: @tzid)
          end

            # Markdown
          if evnt.dtstart.year != current_year
            @markdown << "# #{evnt.dtstart.year}"
            current_year = evnt.dtstart.year
          end
          if evnt.dtstart.month != current_month
            @markdown << "## #{evnt.dtstart.strftime("%B")}"
            current_month = evnt.dtstart.month
          end
          @markdown << " * __#{evnt.dtstart.strftime("%a %m/%d")}:__ [#{evnt.summary.sub(/^Pack 229:/, '').strip}](#{evnt.url})"

        else
          # puts "Skipping: #{title}"
        end

      end
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

cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
pack = PackCalendar.new(cwd)
