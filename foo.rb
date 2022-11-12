#!/bin/env ruby

require 'pry'
require 'net/http'

def get(url)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.path)
  http.request(request)
end

def log(message, level = :debug)
  puts sprintf('[%s] [%5s] %s', Time.now.strftime('%H:%M.%S'), level.to_s.upcase!, message)
  exit(1) if level.eql?(:fatal)
end

input = ARGV.last

log(sprintf('unable to find[%s]', input), :fatal) if input.nil? or ! File.file?(input)

contents = File.read(input)
lines    = contents.split("\n")

results = Hash.new(0)

lines.each do |line|
  next unless line.match(/jpg/)
  line.scan(/value=".*?\.jpg"/).each do |m|
    img = m.gsub('value="', '').chop
    results[img] += 1
  end
end

log(sprintf('found[%s] images', results.keys.size))

results.keys.each do |img|
  url = sprintf('http://photobomb.htb/ui_images/%s', img)
  response = get(url)

  log(sprintf('writing[%s]', img))
  File.open(img, 'wb') do |f|
    f.write(response.body)
  end

end

binding.pry
