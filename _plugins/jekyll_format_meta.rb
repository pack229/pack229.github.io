class Integer
  def hours_x
    self * 60 * 60
  end
  def hour_x
    hours_x
  end
  def minutes_x
    self * 60
  end
  def minute_x
    minutes_x
  end
  def ordinalize
    if (11..13).include?(self % 100)
      "#{self}th"
    else
      case self % 10
        when 1; "#{self}st"
        when 2; "#{self}nd"
        when 3; "#{self}rd"
        else    "#{self}th"
      end
    end
  end
end

class UpcomingPost
  attr_accessor :url
  def initialize(post, meta)
    @p = post
    @m = meta
    @url = @p.url if @p.respond_to?(:url)
  end
  def date
    @m['date']
  end
  def data
    @p.data
  end
  def parse_date(data)
    data = Date.parse(data) if data.is_a?(String) && data.length < 11
    data = DateTime.parse(data) if data.is_a?(String) && data.length > 11
    if @m["time"]
      data = DateTime.parse("#{data.to_s} #{@m["time"]}")
    end
    data
  end
  def upcoming_cal_date
    parse_date([@m['date']].flatten.first)
  end
  def end_cal_date
    if @m['date'].is_a?(Array)
      parse_date(@m['date'].last)
    end
  end
  def end_cal_date_formated
    format_date(end_cal_date)
  end
  def format_date(data)
    if data.is_a?(DateTime)
      data.strftime("%a %-m/%-d @ %l:%M %p")
    elsif data.is_a?(Date)
      data.strftime("%a %-m/%-d")
    else
      data
    end
  end
  def upcoming_cal_date_time_formated
    format_date(upcoming_cal_date)
  end
  def cal_title
    @m['event'] || @p['title']
  end
end

module Jekyll
  module FormatMeta
    def link(name, url)
      "<a href=\"#{url}\">#{name}</a>"
    end

    def format_upcoming(posts)
      upcoming = posts.select{ |i| i['tags'].include?('Upcoming') }.map do |p|
        [p['meta']].flatten.map do |m|
          UpcomingPost.new(p, m)
        end
      end.flatten.select{ |p| p.date }.sort_by{ |p| p.upcoming_cal_date }
      if upcoming.any?
        h = ['<h3>Upcoming Event Calendar</h3>']
        h << '<div class="calendar-cards">'
        upcoming.each do |p|
          h << format_upcoming_item(p)
        end
        h << '</div>'
        h.join("\n")
      else
        ""
      end
    end

    def format_upcoming_item(p)
      h = ['<div class="calendar-card">']
      date = "<p class=\"date\">#{p.upcoming_cal_date_time_formated}</p>"
      name = "<p class=\"name\">#{p.cal_title}</p>"
      if p.end_cal_date_formated
        end_date = "<p class=\"end\">Until: #{p.end_cal_date_formated}</p>"
      end
      if p.url
        date = "<a href=\"#{p.url}\">#{date}</a>"
        name = "<a href=\"#{p.url}\">#{name}</a>"
        end_date = "<a href=\"#{p.url}\">#{end_date}</a>" if end_date
      end
      h << date
      h << name
      h << end_date if end_date
      h << '</div>'
      h.join("\n")
    end

    def format_meta(meta)
      return "" if meta.nil?
      return meta.map{ |m| format_meta(m) }.join("\n") if meta.is_a?(Array)
      umks = (meta.keys.map(&:to_sym) - meta_categories.keys - hidden_categories)
      if umks.any?
        raise "Unknown Meta Key: #{umks.inspect}"
      end
      # Formating
      if meta
        h = ["<ul>"]
        meta_categories.keys.each do |k|
          if i = meta[k.to_s]
            h << "<li>" + format_meta_item([k.to_s, i], meta) + "</li>"
          end
        end
        h << "</ul>"
        h.join("\n")
      end
    end
    def format_meta_for_email(body)
      if body["meta"]
        body["meta"].map do |i|
          format_meta_item(i, body["meta"]) unless hidden_from_calendar.include?(i[0].to_sym)
        end.compact.join("\n") + "\n\n"
      end
    end
    def location_map(value)
      @location_map ||= YAML.load(Pathname.new(File.expand_path(File.dirname(__FILE__))).join("../_data/locations.yaml").read)
      @location_map[value]
    end
    def unmapped_location?(value)
      @unmapped_locations ||= YAML.load(Pathname.new(File.expand_path(File.dirname(__FILE__))).join("../_data/unmapped_locations.yaml").read)
      @unmapped_locations[value]
    end
    def meta_categories
      {
        event: "🪢",
        date: "🗓️ Date",
        time: "⏰ Time",
        location: "📍 Location",
        who: "👤 Who",
        signup: "📋 Signup",
        deadline: "🏁 Deadline",
        cost: "💵 Cost",
        more_info: "🌐 Link",
        contact: "📇 Contact",
        photo_download: "📸",
      }
    end
    def hidden_from_calendar
      [ :date, :time, :location, :event ]
    end
    def hidden_categories
      [ :duration, :uuid ]
    end
    def format_meta_item(input, meta)
      type = input[0].to_sym

      return nil if hidden_categories.include?(type)

      data = input[1]
      title = meta_categories[type]
      data = if type == :signup
        [data].flatten.map do |l|
          if l.is_a?(Hash)
            link(l["title"], l["url"])
          else
            l
          end
        end.join(" and ")
      elsif type == :location && location_data = location_map(data)
        [ link(data, location_data[:site]), link(location_data[:address], location_data[:map]) ].join(" | ")
      elsif type == :date || type == :deadline
        data = [data].flatten.map do |d|
          d = Date.parse(d) unless d.is_a?(Date)
          d.strftime("%A %B #{d.day.ordinalize} %Y")
        end.join(" - ")
      elsif type == :time
        data = data.join(" to ") if data.is_a?(Array)

        if duration_value = meta["duration"]
          # Pulled from Calendar RB
          number, unit = *duration_value.split(" ")
          number = number.to_i
          unit = unit.to_sym
          raise "bad unit" unless [ :minute, :minutes, :hour, :hours ].include?(unit)
          time_length = number.send(:"#{unit}_x")
          #

          time_length = Time.parse(data) + time_length
          time_length = time_length.strftime("%l:%M %p")
          data = [data,time_length].join(" to ")
        end

        data
      elsif type == :contact && data.is_a?(Hash)
        link(data["name"], "mailto:#{data["email"]}")
      elsif type == :more_info
        if data.is_a?(Hash)
          link(data["title"], data["url"])
        else
          link("More Info", data)
        end
      elsif type == :photo_download
        photo_title = File.extname(data) == ".zip" ? "Download Photos" : "Download Photo"
        link(photo_title, data)
      else
        data
      end
      "#{title}: #{data}"
    end

    def first_date(date, format)
      date = DateTime.parse(date.first) if date.is_a?(Array)
      date.strftime(format)
    end
  end

end

Liquid::Template.register_filter(Jekyll::FormatMeta) if Module.const_defined?("Liquid::Template")
