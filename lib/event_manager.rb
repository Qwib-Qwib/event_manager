require 'csv'
require 'erb'
require 'google/apis/civicinfo_v2'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
  number = keep_only_digits(number)
  if number.length < 10 || number.length > 11 || (number.length == 11 && number[0] != '1')
    'Invalid phone number!'
  elsif number.length == 11 && number[0] == '1'
    number.reverse.chop.reverse
  else
    number
  end
end

def keep_only_digits(number)
  number.each_char do |char|
    number.delete!(char) if (48..57).include?(char.codepoints[0]) == false
  end
end

def print_officials_names(zipcode)
  officials = extract_officials_info(zipcode)
  officials_names = officials.each_with_object([]) do |official_info, officials_array|
    officials_array.push(official_info.name.to_s)
  end
  print officials_names.join(', ')
  officials_names.join(', ')
end

def extract_officials_info(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    representatives_info = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    )
    representatives_info.officials
  rescue
    nil
  end
end

def create_form_letter(attendee_info, officials_info)
  template = File.read('form_letter.erb')
  letter = ERB.new(template)
  puts letter.result(binding)
  letter_file = File.open("letters/ID#{attendee_info[0]}_letter", 'w')
  letter_file.write(letter.result(binding))
  letter_file.close
end

def find_busiest_registration_times(attendee_table)
  print_busiest_hours(record_busiest_hours(attendee_table))
  print_busiest_days(record_busiest_days(attendee_table))
end

def record_busiest_hours(attendee_table)
  attendee_table.rewind
  list = establish_hours_list(attendee_table)
  max_hour_count = list.max { |pair1, pair2| pair1[1] <=> pair2[1] }
  list.delete_if { |_key, value| value != max_hour_count[1] }
end

def establish_hours_list(attendee_table)
  attendee_table.each_with_object({}) do |row, hours_list|
    hour = Time.strptime(row[:regdate].split(' ')[1], '%H:%M').hour
    hours_list[hour] += 1 if hours_list.key?(hour) == true
    hours_list[hour] = 1 if hours_list.key?(hour) == false
  end
end

def print_busiest_hours(hours_hash)
  total_hours = hours_hash.keys
  if total_hours.size == 1
    puts "Looks like the best hour for registrations is: #{total_hours[0]}."
  else
    puts "Looks like the best hours for registrations are: #{hours_hash.keys.to_s.delete('[').delete(']')}."
  end
end

def record_busiest_days(attendee_table)
  attendee_table.rewind
  list = establish_days_list(attendee_table)
  max_day_count = list.max { |pair1, pair2| pair1[1] <=> pair2[1] }
  list.delete_if { |_key, value| value != max_day_count[1] }
end

def establish_days_list(attendee_table)
  attendee_table.each_with_object({}) do |row, days_list|
    day_code = Date.strptime(row[:regdate].split(' ')[0], '%D').wday
    day = find_day(day_code)
    days_list[day] += 1 if days_list.key?(day) == true
    days_list[day] = 1 if days_list.key?(day) == false
  end
end

def find_day(day_code)
  case day_code
  when 0 then 'Sunday'
  when 1 then 'Monday'
  when 2 then 'Tuesday'
  when 3 then 'Wednesday'
  when 4 then 'Thursday'
  when 5 then 'Friday'
  when 6 then 'Saturday'
  end
end

def print_busiest_days(days_hash)
  total_days = days_hash.keys
  if total_days.size == 1
    puts "Looks like the best day for registrations is: #{total_days[0]}."
  else
    puts "Looks like the best days for registrations are: #{total_days.keys.to_s.delete('[').delete(']')}."
  end
end

puts 'Event Manager initialized!'
puts 'There is no data to process!' if File.exist?('event_attendees.csv') == false
if File.exist?('event_attendees.csv')
  content = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)
end
Dir.mkdir('letters') unless Dir.exist?('letters')
content.each do |row|
  row[:zipcode] = clean_zipcode(row[:zipcode])
  row[:homephone] = clean_phone_number(row[:homephone])
  print "#{row[:first_name]} #{row[:zipcode]} #{row[:homephone]} "
  begin
    print_officials_names(row[:zipcode])
  rescue
    print 'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
  puts ''
  create_form_letter(row, extract_officials_info(row[:zipcode]))
end
find_busiest_registration_times(content)
