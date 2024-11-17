#!/usr/bin/env ruby

require 'icalendar'
require 'icalendar/tzinfo'
require 'pathname'

$cwd = Pathname.new(File.expand_path(File.dirname(__FILE__)))
cal = Icalendar::Calendar.new
cal.x_wr_calname = 'Pack 229'

event_start = DateTime.new 2024, 12, 16, 18, 30, 0
event_end = DateTime.new 2024, 12, 16, 19, 30, 0

tzid = "America/Los_Angeles"
tz = TZInfo::Timezone.get tzid
timezone = tz.ical_timezone event_start
cal.add_timezone timezone

cal.event do |e|
  e.summary     = "229 Pack Meeting"
  e.description = "Details"
  e.dtstart = Icalendar::Values::DateTime.new event_start, 'tzid' => tzid
  e.dtend   = Icalendar::Values::DateTime.new event_end, 'tzid' => tzid
  e.ip_class    = "PUBLIC"
  e.url = 'https://hsspack229.org/2024/11/06/december-pack-meeting/'
  e.organizer = Icalendar::Values::CalAddress.new("mailto:contact@hsspack229.org", cn: 'Pack 229')
end
# DTSTAMP:20241117T202728Z
# UID:7942265c-f8ad-4569-8b3c-715647798bea

puts cal.to_ical

$cwd.join("../ics/pack229.ics").write(cal.to_ical)
