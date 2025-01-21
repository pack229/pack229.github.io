#!/usr/bin/env ruby

require 'icalendar'
require 'icalendar/tzinfo'
require 'vcardigan'
require 'pathname'
require 'rack'

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
    attr_reader :head, :body, :event_start, :event_end, :tzid

    def initialize(cwd, tzid, head, body, source_file)
      @cwd = cwd
      @tzid = tzid
      @source_file = source_file

      @head = head
      @meta = head["meta"] || {}
      @body = clean_body((Meta.new.format_meta_for_email(@head) || "") + (body || ""))

      set_dates
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
          link = "#{$base_url}#{link}" unless link.match(/^http/)
          num = if pos = links.map{ |it| it[:url] }.index(link)
            pos+1
          else
            links << { url: link, title: tag.inner_text }
            links.count
          end
          "#{tag.inner_text} [see link below]"
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

      if links.any?
        links.each_with_index do |l, i|
          body << "#{l[:title]}: #{l[:url]}\n\n"
        end
      end
      body
    end

    def title
      return @title unless @title.nil?

      @title = head["title"].sub(" - Save The Date", "")
      @title = "Pack Meeting" if @title.match(" Pack Meeting")
      @title
    end

    def url
      return @url unless @url.nil?

      if head['date']
        post_date = Icalendar::Values::DateTime.new(head['date'], tzid: tzid)
        if post_date < Time.now
          url_parts = File.basename(@source_file.to_s, ".md").split("-")
          @url = "#{$base_url}/#{url_parts[0..2].join("/")}/#{url_parts[3..-1].join("-")}"
        end
      end

      @url
    end

    def uuid
      head["uuid"].downcase
    end

    def mtime
      @source_file.mtime
    end

    def duration
      if duration_value = @meta["duration"]
        number, unit = *duration_value.split(" ")
        number = number.to_i
        unit = unit.to_sym
        raise "bad unit" unless [ :minute, :minutes, :hour, :hours ].include?(unit)
        number.send(unit)
      else
        60.minutes
      end
    end

    def location
      if loc = @meta["location"]
        loc_data = Meta.new.location_map(loc)
        if loc_data.nil?
          loc
        else
          "#{loc}\n#{loc_data[:address]}"

          # file_name = "#{loc.downcase.gsub(/[^a-z0-9 ]/, "").gsub(" ", "_")}.vcf"
          # card = VCardigan.create
          # card.name(loc)
          # card.fullname(loc)
          # card[:site].label('Site')
          # card[:site].url(loc_data[:site])
          # card[:map].label('Map')
          # card[:map].url(loc_data[:map])
          # loc_data[:address]
          # @cwd.join("../ics/vcard/#{file_name}").write(card.to_s)
          # "ALTREP=\"#{$base_url}/ics/vcard/#{file_name}\": #{loc}"
        end
      end
    end

    def location_structured
      if loc = @meta["location"]
        if loc_data = Meta.new.location_map(loc)
          params = Rack::Utils.parse_query(URI(loc_data[:map]).query)
          raise "missing ll from map" if params["ll"].nil?
          Icalendar::Values::Uri.new("geo:#{params["ll"]}", {
            "X-TITLE" => loc,
            "X-ADDRESS" => loc_data[:address]
          })
        else
          raise "missing location data: #{loc}" unless Meta.new.unmapped_location?(loc)
        end
      end
    end

    def set_dates
      date = @meta["date"]
      @valid = !(head["calendar"] || "").split(",").include?("skip")
      if @valid
        if date.is_a?(Array) && date.length == 2
          event_start = DateTime.parse(date[0])
          @event_start = Icalendar::Values::DateTime.new(event_start, tzid: tzid)
          event_end = DateTime.parse(date[1])
          @event_end = Icalendar::Values::DateTime.new(event_end, tzid: tzid)
        elsif date.is_a?(Date)
          event_start = DateTime.parse("#{date} #{@meta["time"]}")
          @event_start = Icalendar::Values::DateTime.new(event_start, tzid: tzid)
          @event_end = Icalendar::Values::DateTime.new(event_start + duration, tzid: tzid)
        else
          @valid = false
        end
      end
    end

  end

  attr_accessor :cal
  def initialize(cwd, calendar_title)
    @cwd = cwd
    @cal = Icalendar::Calendar.new
    @cal.add_timezone(TZInfo::Timezone.get(tzid).ical_timezone(Time.now))
    @cal.x_wr_calname = calendar_title
    @posts = []
    @markdown = []
  end
  def run!
    load_events_from_posts!
    check_posts!
    generate!
  end
  def posts
    @posts
  end
  def sorted_posts
    @sorted_posts ||= posts.select{ |e| e.valid? }.sort_by{ |e| e.event_start }
  end
  def tzid
    "America/Los_Angeles"
  end

  def yaml_load(data)
    YAML.load(data, permitted_classes: [Date])
  end

  def markdown_load(data)
    Kramdown::Document.new(data, input: 'GFM').to_html
  end

  def load_events_from_yaml!(file)
    source_file = @cwd.join("../_data/calendar_#{file}.yaml")
    yaml_load(source_file.read).each do |data|
      @posts << Event.new(@cwd, tzid, data, nil, source_file)
    end
  end

  def load_events_from_posts!
    dir = @cwd.join("../_posts")
    dir.entries.map do |path|
      next if path.basename.to_s[0] == "."
      source_file = dir.join(path)
      parts = source_file.read.split("---")
      @posts << Event.new(@cwd, tzid, yaml_load("---\n" + parts[1].strip + "\n"), markdown_load(parts[2..-1].join("\n").strip), source_file)
    end.compact
  end

  def check_posts!
    # raise "Duplicate UUIDs" if get_all_posts.map(&:uuid).count != get_all_posts.map(&:uuid).uniq.count
    used_uuids = []
    posts.each do |p|
      raise "Duplicate UUID for #{p.file}" if used_uuids.include?(p.uuid)
      used_uuids << p.uuid
      # TODO raise "Check Date for #{p.file}" if p.head['date'].strftime("%Y-%m-%d") != File.basename(p.file).split("-")[0..2].join("-")
    end
  end

  def generate!
    current_year = nil
    current_month = nil

    sorted_posts.each do |post|

      # iCal
      cal.event do |e|
        e.summary = "Pack 229: #{post.title}"
        e.description = post.body
        e.url = post.url unless post.url.nil?
        e.dtstart = post.event_start
        e.dtend   = post.event_end
        e.ip_class = "PUBLIC"
        e.location = post.location if post.location
        e.x_apple_structured_location = post.location_structured if post.location_structured
        e.organizer = Icalendar::Values::CalAddress.new("mailto:contact@hsspack229.org", cn: 'Pack 229')
        e.uid = post.uuid
        e.dtstamp = Icalendar::Values::DateTime.new(post.mtime, tzid: tzid)
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
    # ical_string.gsub!("LOCATION:ALTREP", "LOCATION;ALTREP")
    @cwd.join("../ics/#{file_name}.ics").write(ical_string)
  end
  def save_markdown!
    token = "<!-- Generated Calendar -->"
    file = @cwd.join("../calendar.md")
    calendar = file.read.split(token)[0] + token + "\n\n" + @markdown.join("\n\n")
    file.write(calendar)
  end
end

pack = PackCalendar.new(cwd, 'Pack 229')
pack.run!
pack.save_ics!("pack229")
pack.save_markdown!

[ "6" ].each do |den_number|
  den = PackCalendar.new(cwd, "Pack 229 & Den #{den_number}")
  den.load_events_from_yaml!("den#{den_number}")
  den.run!
  den.save_ics!("pack229-den#{den_number}")
end
