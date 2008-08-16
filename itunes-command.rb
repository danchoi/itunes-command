#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby

# If the shebang line doesn't point to your OS X installation of ruby, find it
# and correct the path above.
#
# itunes-command.rb
#
# Requirements: 
#
#   OS X Leopard
#
# Instructions: 
#
#   Save this file as 'itunes-command.rb' or whatever else you wish to call it.
#
#   Run it with either:
#
#     ruby itunes-command.rb
#
#   or 
#
#     ./itunes-command.rb 
#
#   or itunes-command.rb
#
#   The 2nd and 3rd options assume that you made the file executable with 
#
#     chmod u+x itunes-command.rb
#
#   The 3d options also assumes that itunes-command.rb is on your PATH.
#
# Author: Daniel Choi
# Location: Cambridge, MA
# Affiliation: http://betahouse.org
# Email: dhchoi@gmail.com
# Project Homepage: http://danielchoi.com/software/itunes-command.html
#
# License: MIT
#
# Copyright (c) 2008 Daniel Choi
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

require 'rubygems' 
$:.unshift File.dirname(__FILE__)
require 'readline'
require 'osx/cocoa'
OSX.require_framework 'ScriptingBridge'

class ITunes
  QUEUE_PLAYLIST = 'itunes-command'
  def initialize
    @app = OSX::SBApplication.applicationWithBundleIdentifier("com.apple.iTunes")
  end

  # Delegate all other methods to the SBAppliation object for iTunes
  def method_missing(message, *args)
    @app.send(message, *args)
  end

  def party_shuffle
    playlists.detect {|x| x.name == "Party Shuffle"}
  end

  def playlists
    @app.sources.first.playlists
  end

  def playlist_by_name(name)
    playlists.detect {|p| p.name == name}
  end

  def library
    playlists.first
  end

  def artists(playlist=library)
    return {} if playlist.tracks.empty?
    artists = playlist.tracks.arrayByApplyingSelector("artist").select {|x| x.to_s =~ /\w/}
    # count tracks per artist, which is represented to number of occurrences
    artist = Hash.new(0)
    artists.each do |name|
      artist[name.to_s] += 1
    end
    artist
  end

  # Pass in a string to get matching tracks. Pass in an integer to search by 
  # databaseID
  def find_track(query)
    if query.is_a?(String)
      library.searchFor_only(query, nil)
    elsif query.is_a?(Integer) # lookup by databaseID
      predicate = OSX::NSPredicate.predicateWithFormat("databaseID == #{query}")
      # assume that only one track matches, and return it
      library.tracks.filteredArrayUsingPredicate(predicate).first
    end
  end

  def find_tracks(track_ids)
    predicate = OSX::NSPredicate.predicateWithFormat("databaseID IN {%s}" % track_ids.join(','))
    library.tracks.filteredArrayUsingPredicate(predicate)
  end

  def add_track_to_playlist(track, playlist)
    if playlist.is_a?(String)
      playlist = playlist_by_name(playlist)
    end
    track = track.duplicateTo(playlist)
    #    The following does not work:
    #    arg1 = OSX::NSArray.arrayWithArray([track])
    #    puts arg1.class
    #    puts playlist.class
    #    puts @app.add_to_(arg1, playlist)
  end

  def add_tracks_to_playlist(tracks, playlist, credit=nil)
    if playlist.is_a?(String)
      playlist = playlist_by_name(playlist)
    end
    if tracks.is_a?(Array) # need to convert Ruby array into NSArray
      tracks = OSX::NSArray.arrayWithArray(tracks)
    end
    tracks.makeObjectsPerformSelector_withObject("setEnabled:", 1)
    if credit
      tracks.makeObjectsPerformSelector_withObject("setComment:", credit)
    end
    # Note the colon in the selector string
    tracks.makeObjectsPerformSelector_withObject("duplicateTo:", playlist)
    # enable all tracks - does not work
  end

  def remove_track_from_playlist(track, playlist)
    # looks dangerous!
    return
    track.delete
  end

  def create_playlist(name)
    return if playlist_by_name(name) 
    props = {:name => name}
    playlist = @app.classForScriptingClass("playlist").alloc.initWithProperties(props)
    playlists.insertObject_atIndex(playlist, 0)
    playlist
  end

  # makes sure the queue playlist is selected. importance for pause/play, skip,
  # etc.
  def select_queue_playlist
    browserWindows.first.view = queue
  end

  # This is the playlist that itunes-rails uses
  def queue
    playlist_by_name(QUEUE_PLAYLIST) || create_playlist(QUEUE_PLAYLIST)
  end

  def queue_track(track)
    add_track_to_playlist(track, queue)
  end

  def queue_tracks(tracks,credit=nil)
    add_tracks_to_playlist(tracks, queue, credit)
  end

  def clear_queue
    queue.tracks.removeAllObjects
  end

  def create_artwork_for_current_track
    # check if it exists
    track = @app.currentTrack

    return if artwork_file(@app.currentTrack)
    return if @app.currentTrack.artworks.empty?
    puts "Trying to create artwork for #{track.name.to_s}"
    extension = `osascript -e '
    tell application "iTunes"
      set theTrack to current track
      set artData to (data of artwork 1 of theTrack) as picture
      set artFormat to (format of artwork 1 of theTrack) as string
      
      if artFormat contains "JPEG" then
        set extension to ".jpg"
      else if artFormat contains "PNG" then
        set extension to ".png"
      end if
      set fileName to "test"
      set tempArtFile to "#{RAILS_ROOT}/public/tempfile" & extension
      set fileRef to (open for access tempArtFile write permission 1)
      write artData starting at 0 to fileRef as picture
      close access fileRef
      return extension as string
    end tell' `

    filename = artwork_filename(@app.currentTrack)
    puts filename
    
    `tail -c+223 #{RAILS_ROOT}/public/tempfile.* > #{RAILS_ROOT}/public/artwork/#{filename}#{extension.strip} && rm #{RAILS_ROOT}/public/tempfile.*`
  end

  def create_artwork_for_track(track)

    if track.artworks.empty?
      puts "#{track.name.to_s} has no artwork"
      return
    end
    puts "Trying to create artwork for #{track.name.to_s} #{track.databaseID}"
    extension = `osascript -e '
    tell application "iTunes"
      set theTrack to (item 1 of (every track of library playlist 1 whose database ID is #{track.databaseID}))

      set artData to (data of artwork 1 of theTrack) as picture
      set artFormat to (format of artwork 1 of theTrack) as string
      
      if artFormat contains "JPEG" then
        set extension to ".jpg"
      else if artFormat contains "PNG" then
        set extension to ".png"
      end if
      set fileName to "test"
      set tempArtFile to "#{RAILS_ROOT}/public/tempfile" & extension
      set fileRef to (open for access tempArtFile write permission 1)
      write artData starting at 0 to fileRef as picture
      close access fileRef
      return extension as string
    end tell  ' `

    filename = artwork_filename(track)
    puts filename
    
    `tail -c+223 #{RAILS_ROOT}/public/tempfile.* > #{RAILS_ROOT}/public/artwork/#{filename}#{extension.strip} && rm #{RAILS_ROOT}/public/tempfile.*`

  end


  def artwork_filename(track)
    # Keep the filenames short, esp. in the case of classical music artist and
    # album data, which are often way too long
    # puts "In artwork_filename method"
    return unless track

    return unless track.artist
    artist = track.artist.to_s.strip.gsub(/[\W\-_]*/,'')[0,15]
    album = track.album.to_s.strip.gsub(/[\W\-_]*/,'')[0,15]
    "%s-%s" % [artist, album]
  end

  def artwork_file(track)
    filename = artwork_filename(track) 
    return unless filename
    web_path = "/artwork/" + filename
    filename = RAILS_ROOT + "/public" + web_path

    return web_path + ".jpg" if File.exist?( filename + ".jpg" )
    return web_path + ".png" if File.exist?( filename + ".png" )
    nil
  end

  def find_songs_without_art
    library.tracks.each do |track|
      if track.artworks.empty?
        puts track.name
      end
    end
  end
end
class ItunesCommand 
  VERSION = '1.0.0'
  attr_accessor :playlist_mode
  def initialize
    @i = ITunes.new
    @playlists = []
    @tracks = []
    @playlist_mode = false
  end

  def parse(method, *args)
    self.send method, args
  end

  def search(string=nil)
    unless string
      puts "Please enter a search string"
      return
    end
    @tracks = @i.find_track(string)
    print_names(@tracks)
  end

  def search_artist(string=nil)
    unless string
      puts "Please enter a search string"
      return
    end
    @tracks = @i.find_track(string)
    print_names(@tracks)
  end

  def print_names(items)
    items =  Array(items)
    rows = []
    items.each_with_index do |t, i|
      begin
        puts("%2d %s : %s" % [i, t.artist, t.name])
      rescue
      end
    end
    items
  end

  def play(index)
    if @tracks.empty?
      puts "No tracks in buffer yet. Try searching."
      return
    end
    track = @tracks[index.to_i]
    puts "Playing '#{track.name}' by #{track.artist} from #{track.album}"
    track.playOnce(1)
  end

  def stop
    @i.stop
  end

  def volume(level=nil)
    unless level
      puts "The volume is #{@i.soundVolume} out of 100"
      return
    end
    @i.soundVolume = level
    puts "The volume set to #{@i.soundVolume} out of 100"
  end

  def +(steps=10)
    @i.soundVolume = @i.soundVolume + steps.to_i
    volume
  end

  def -(steps=10)
    @i.soundVolume = @i.soundVolume - steps.to_i
    volume
  end

  def playlists
    @playlist_mode = true
    puts "Showing playlists"
    playlists = @i.playlists
    playlists.each_with_index do |p,i|
      puts("%2d %s" % [i, p.name])
    end
  end

  def select_playlist(index)
    @current_playlist = @i.playlists[index.to_i]
    # show tracks
    @tracks = @current_playlist.tracks
    print_names(@tracks)
    @playlist_mode = false
  end

  def playlist(index)
    @playlists ||= playlists
    puts @playlists[index].name
  end

  def artists
    rows = []
    (@artists=@i.artists).keys.sort_by {|x| x.downcase}.each_with_index  do |k, i|
      rows << ("%s (%s tracks)" % [k, @artists[k]])
    end
    pager(rows)
  end

  def pager(rows)
    out = rows.join("\n")
    IO.popen("less", "w") do |less|
      less.puts out
      less.close_write
    end
  end
end

HELP = <<END
itunes-command

Commands:

q                   quit
h                   show commands
s <string>          searches for tracks matching <string>
<track number>      plays a track (assumes you've done a search and got results)
a                   lists all artists in the library
v                   show the current volume level
v <level>           sets the volume level (1-100)
+ <increment>       increases the volume by <increment>; default is 10 steps
- <increment>       decreases the volume by <increment>; default is 10 steps
x                   stop
p                   shows all playlists 
END

COMMANDS = { 's' => :search, 
'x' => :stop , 'play' => :play, 'v' => :volume, 'a' => :artists, '+' => :+, '-' => '-',
'p' => :playlists, 'select_playlist' => :select_playlist }

if __FILE__ == $0
  i = ItunesCommand.new
  puts HELP
  loop do
    command = Readline.readline(">> ").chomp
    if command =~ /^q/
      exit
    elsif command =~ /^h/
      puts HELP
      next
    end
    args = command.split(' ')
    if args.first =~ /\d+/
      if i.playlist_mode
        args.unshift 'select_playlist'
      else
        args.unshift 'play'
      end
    end
    method = COMMANDS[args.shift]
    if method.nil?
      puts "Sorry, I don't recognize that command."
      next
    end
    begin
      args.empty? ? i.send(method) : i.send(method, args.join(' '))
    rescue ArgumentError
      puts "Invalid command."
    end
  end
end

