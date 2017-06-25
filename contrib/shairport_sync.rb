#!/usr/bin/env ruby

SERVER = 'http://localhost:3000/'

require 'net/http'

uri = URI.parse("#{SERVER}av/shairport_sync/#{ARGV[1]}")

if ARGV[0] == 'start'
  response = Net::HTTP.post(uri, '')
  puts response.body
else
  http = Net::HTTP.new(uri.host, uri.port)
  delete = Net::HTTP::Delete.new(uri.path)
  http.request(delete)
end
