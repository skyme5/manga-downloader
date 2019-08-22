#!/usr/bin/ruby
# @Author: Aakash Gajjar
# @Date:   2019-08-13 19:40:07
# @Last Modified by:   Sky
# @Last Modified time: 2019-08-13 20:02:55

require 'optparse'

require_relative 'MangaDownloader'

MANGA_DIR = "Z:/Books/Manga"
p ARGV
if ARGV.length > 0
  download = MangaDownloader.new()
  download.download
else
  manga = Dir.entries(MANGA_DIR)[2..-1].select{|e| File.directory?(File.join(MANGA_DIR, e))}

  manga.each{
    |m|
    download = MangaDownloader.new(m)
    download.download
  }
end
