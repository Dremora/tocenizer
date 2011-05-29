#!/usr/bin/env ruby

require 'rbrainz'
require 'mb-discid'

module MusicBrainz
  class Tocenizer
    def initialize
      @sectors = 0
      @offsets = []
    end

    def parse_line(line)
      r = /\s*[0-9]+\s+\|(?:\s+[0-9]{1,2}:[0-9]{2}[\.:][0-9]{2}\s+\|){2}\s+([0-9]+)\s+\|\s+([0-9]+)\s*/
      if matches = r.match(line)
        start_sector = matches[1].to_i
        end_sector = matches[2].to_i

        length = end_sector - start_sector + 1
        @sectors += (start_sector + 150) if @sectors == 0
        @sectors += length

        @offsets.push start_sector + 150
      elsif @sectors > 0
        return false
      end
      true
    end

    def parsed?
      @sectors > 0
    end

    def discid
      nil unless parsed?
      calculate!
      @disc.id
    end

    def toc
      nil unless parsed?
    end

    def calculate!
      unless @disc
        @disc = MusicBrainz::DiscID.new
        @disc.put 1, @sectors, @offsets
      end
    end

    def submission_url
      nil unless parsed?
      "http://musicbrainz.org/cdtoc/attach?toc=1%20" +
      "#{tracks_count}%20#{@sectors}%20" +
      @offsets.join('%20')
    end

    def tracks_count
      @offsets.length
    end

    def releases
      [] unless parsed?
      @releases ||= Webservice::Query.new.get_releases(
        :discid => discid,
        :cdstubs => false
      ).to_collection
    end
  end
end

def show_help
  puts 'log_to_toc v0.1 - extracts MusicBrainz TOC and Disc ID from EAC log files.'
  puts "Usage: log_to_toc [filename]"
  puts "If run without arguments, it will read from stdin. Press Ctrl-C to view results."
  puts "Run with --help to view this message."
end

if ARGV.length == 1 && ARGV[0] == '--help'
  show_help
  exit
end

# # Read log from file or stdin
log = MusicBrainz::Tocenizer.new
if ARGV.length == 0 && $stdin.tty?
  show_help
  begin
    $stdin.each_line {|line| break unless log.parse_line(line) }
  rescue Interrupt
  end
else
  ARGF.each_line {|line| break unless log.parse_line(line) }
end

# Finalize parsing and get Disc ID
puts ""
if !log.parsed?
  puts "Couldn't locate TOC."
else
  puts "#{log.tracks_count} track#{'s' if log.tracks_count > 1}"
  puts "Disc ID: #{log.discid}"
  releases = log.releases
  if releases.size > 0
    puts "This Disc ID has already been submitted to MusicBrainz."
    puts "List of releases:"
    releases.each do |release|
      puts "* #{release.artist} - #{release.title}"
      puts "  #{release.id}"
    end
  else
    puts "Submission URL: #{log.submission_url}"
  end
end
