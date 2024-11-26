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
    def format_meta_for_email(body)
      if body["meta"]
        body["meta"].map do |i|
          format_meta(i) unless [ :date, :time ].include?(i[0].to_sym)
        end.compact.join("\n\n") + "\n\n"
      end
    end
    def location_map(value)
      map = {
        "Camp Cheesebrough" => {
          site: "https://svmbc.org/chesebrough-scout-reservation/",
          address: "26005 Big Basin Wy, Los Gatos, CA 95033",
          map: "https://maps.apple.com/?address=26005%20CA-9,%20Los%20Gatos,%20CA%20%2095033,%20United%20States&auid=10538835573111821490&ll=37.248338,-122.145724&lsp=9902&q=Camp%20Cheesebrough",
        },
        "Christmas in the Park" => {
          site: "https://christmasinthepark.com",
          address: "194 S Market St, San Jose, CA 95113",
          map: "https://maps.apple.com/?ll=37.333191,-121.890210&q=Downtown%20San%20Jose%20%E2%80%94%20San%20Jose&spn=0.009366,0.016926&t=m",
        }
      }[value]
      map ? map[:map] : nil
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
        photo_download: "📸",
      }[type]
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
      elsif type == :location && data == "Christmas in the Park"
        [ link("Christmas in the Park", "https://maps.apple.com/?address=1%20Paseo%20de%20San%20Antonio%0ASan%20Jose,%20CA%20%2095113%0AUnited%20States&auid=12608692531698440874&ll=37.333000,-121.890210&lsp=9902&q=Christmas%20in%20the%20Park") ].join(" | ")
      elsif type == :date || type == :deadline
        data = [data].flatten.map{ |d| d.strftime("%A %B #{d.day.ordinalize} %Y") }.join(" - ")
      elsif type == :contact && data.is_a?(Hash)
        link(data["name"], "mailto:#{data["email"]}")
      elsif type == :more_info
        link("More Info", data)
      elsif type == :photo_download
        link("Download Photo", data)
      else
        data
      end
      "#{title}: #{data}"
    end
  end
end

Liquid::Template.register_filter(Jekyll::FormatMeta) if Module.const_defined?("Liquid::Template")
