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
    def format_meta(meta)
      return "" if meta.nil?
      umks = (meta.keys.map(&:to_sym) - meta_categories.keys - hidden_categories)
      if umks.any?
        raise "Unknown Meta Key: #{umks.inspect}"
      end
      # Formating
      if meta
        h = ["<ul>"]
        meta_categories.keys.each do |k|
          if i = meta[k.to_s]
            h << "<li>" + format_meta_item([k.to_s, i]) + "</li>"
          end
        end
        h << "</ul>"
        h.join("\n")
      end
    end
    def format_meta_for_email(body)
      if body["meta"]
        body["meta"].map do |i|
          format_meta_item(i) unless [ :date, :time, :location ].include?(i[0].to_sym)
        end.compact.join("\n\n") + "\n\n"
      end
    end
    def location_map(value)
      {
        "Camp Cheesebrough" => {
          site: "https://svmbc.org/chesebrough-scout-reservation/",
          address: "26005 Big Basin Wy, Los Gatos, CA 95033",
          map: "https://maps.apple.com/?address=26005%20CA-9,%20Los%20Gatos,%20CA%20%2095033,%20United%20States&auid=10538835573111821490&ll=37.248338,-122.145724&lsp=9902&q=Camp%20Cheesebrough",
        },
        "Christmas in the Park" => {
          site: "https://christmasinthepark.com",
          address: "194 S Market St, San Jose, CA 95113",
          map: "https://maps.apple.com/?ll=37.333191,-121.890210&q=Downtown%20San%20Jose%20%E2%80%94%20San%20Jose&spn=0.009366,0.016926&t=m",
        },
        "Ed R. Levin County Park" => {
          site: "https://parks.santaclaracounty.gov/locations/ed-r-levin-county-park",
          address: "3100 Calaveras Road, Milpitas, CA 95035",
          map: "https://maps.apple.com/?address=3100%20Calaveras%20Rd,%20Milpitas,%20CA%20%2095035,%20United%20States&auid=14976263126931611544&ll=37.446093,-121.856453&lsp=9902&q=Youth%20Area%20Group%20Campsite&t=h"
        },
        "California Academy of Sciences" => {
          site: "https://www.calacademy.org/",
          address: "55 Music Concourse Dr, San Francisco, CA 94118",
          map: "https://maps.apple.com/?address=55%20Music%20Concourse%20Dr,%20San%20Francisco,%20CA%20%2094118,%20United%20States&auid=14911865229426143713&ll=37.769846,-122.466080&lsp=9902&q=California%20Academy%20of%20Sciences&t=h"
        },
        "Chase Center" => {
          site: "https://www.chasecenter.com",
          address: "1 Warriors Way, San Francisco, CA 94158",
          map: "https://maps.apple.com/?address=1%20Warriors%20Way,%20San%20Francisco,%20CA%2094158,%20United%20States&auid=10109771882556141541&ll=37.767829,-122.387426&lsp=9902&q=Chase%20Center&t=h"
        },
        "SAP Center" => {
          site: "https://www.sapcenter.com",
          address: "525 W Santa Clara St, San Jose, CA 95113",
          map: "https://maps.apple.com/?address=525%20W%20Santa%20Clara%20St,%20San%20Jose,%20CA%2095113,%20United%20States&auid=16379594824313942166&ll=37.332760,-121.902051&lsp=9902&q=SAP%20Center&t=h"
        },
        "Holy Spirit Parish" => {
          site: "https://holyspiritchurch.org",
          address: "1200 Redmond Ave, San Jose, CA  95120",
          map: "https://maps.apple.com/?address=1200%20Redmond%20Ave,%20San%20Jose,%20CA%20%2095120,%20United%20States&auid=12969366485807214797&ll=37.228816,-121.874444&lsp=9902&q=Holy%20Spirit%20Parish&t=h"
        }
      }[value]
    end
    def unmapped_locations
      []
    end
    def meta_categories
      {
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
    def format_meta_item(input)
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
        data
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

    def first_date(date, format)
      date = DateTime.parse(date.first) if date.is_a?(Array)
      date.strftime(format)
    end
  end
end

Liquid::Template.register_filter(Jekyll::FormatMeta) if Module.const_defined?("Liquid::Template")
