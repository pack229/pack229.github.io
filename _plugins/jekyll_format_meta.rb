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
      }[type]
      if type == :signup
        data = [data].flatten.map{ |l| "<a href=\"mailto:#{l["link"]}\">#{l["title"]}</a>" }.join(" and ")
      end
      data = data.strftime("%A %B #{data.day.ordinalize} %Y") if type == :date || type == :deadline
      data = "<a href=\"mailto:#{data["email"]}\">#{data["name"]}</a>" if type == :contact && data.is_a?(Hash)
      "#{title}: #{data}"
    end
  end
end
Liquid::Template.register_filter(Jekyll::FormatMeta)
