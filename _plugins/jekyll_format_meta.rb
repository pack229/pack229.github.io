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
    def link(name, url)
      "<a href=\"#{url}\">#{name}</a>"
    end
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
            link(l["title"], l["url"])
          else
            l
          end
        end.join(" and ")
      elsif type == :location && data == "Camp Cheesebrough"
        [ link("Camp Cheesebrough", "https://svmbc.org/chesebrough-scout-reservation/"), link("26005 Big Basin Wy, Los Gatos, CA 95033", "https://maps.apple.com/?address=26005%20CA-9,%20Los%20Gatos,%20CA%20%2095033,%20United%20States&auid=10538835573111821490&ll=37.248338,-122.145724&lsp=9902&q=Camp%20Cheesebrough") ].join(" | ")
      elsif type == :date || type == :deadline
        data = [data].flatten.map{ |d| d.strftime("%A %B #{d.day.ordinalize} %Y") }.join(" - ")
      elsif type == :contact && data.is_a?(Hash)
        link(data["name"], "mailto:#{data["email"]}")
      elsif type == :more_info
        link("More Info", data)
      else
        data
      end
      "#{title}: #{data}"
    end
  end
end
Liquid::Template.register_filter(Jekyll::FormatMeta)
