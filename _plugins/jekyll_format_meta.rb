class Integer
  def hours
    self * 60 * 60
  end
  def hour
    hours
  end
  def minutes
    self * 60
  end
  def minute
    minutes
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

module Jekyll
  module FormatMeta
    def link(name, url)
      "<a href=\"#{url}\">#{name}</a>"
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
          format_meta_item(i, body["meta"]) unless [ :date, :time, :location ].include?(i[0].to_sym)
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
        signup: "📋 Signup",
        deadline: "🏁 Deadline",
        cost: "💵 Cost",
        more_info: "🌐 Link",
        contact: "📇 Contact",
        photo_download: "📸",
      }
    end
    def hidden_categories
      [ :duration ]
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
          time_length = number.send(unit)
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
