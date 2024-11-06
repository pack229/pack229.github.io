class Integer
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
    def format_meta(input)
      type = input[0].to_sym
      data = input[1]
      title = {
        location: "📍 Location",
        date: "🗓️ Date",
        time: "⏰ Time",
        cost: "💵 Cost",
        contact: "📇 Contact",
        deadline: "🏁 Deadline",
        signup: "📋 Signup",
        more_info: "🌐 Link",
      }[type]
      # * 📍 Location: Camp Cheesebrough, 26005 Hwy 9, Los Gatos, CA
      data = if type == :signup
        [data].flatten.map do |l|
          if l.is_a?(Hash)
            "<a href=\"#{l["url"]}\">#{l["title"]}</a>"
          else
            l
          end
        end.join(" and ")
      elsif type == :date || type == :deadline
        data = [data].flatten.map{ |d| d.strftime("%A %B #{d.day.ordinalize} %Y") }.join(" - ")
      elsif type == :contact && data.is_a?(Hash)
        "<a href=\"mailto:#{data["email"]}\">#{data["name"]}</a>"
      elsif type == :more_info
        "<a href=\"mailto:#{data}\">More Info</a>"
      else
        data
      end
      "#{title}: #{data}"
    end
  end
end
Liquid::Template.register_filter(Jekyll::FormatMeta)
