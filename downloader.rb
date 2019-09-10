#!/usr/bin/ruby
# @Author: Aakash Gajjar
# @Date:   2019-08-13 19:40:07
# @Last Modified by:   Sky
# @Last Modified time: 2019-08-24 22:58:45

require 'optparse'
require 'json'

require_relative 'MangaConfig'
require_relative 'MangaDownloader'
require_relative 'LNDownloader'

MANGA_DIR = "Z:/Books/Manga"

if ARGV.length > 0
  config = MangaConfig.new()

  download = MangaDownloader.new(config.get)
  download.download
else
  manga = Dir.entries(MANGA_DIR)[2..-1].select{|e| File.directory?(File.join(MANGA_DIR, e))}

  manga.each{
    |m|

    config_path = File.join(MANGA_DIR, m, m + ".json")
    next if !File.exist?(config_path)

    config = JSON.parse(File.read(config_path))

    if config["ln"]
      download = LNDownloader.new(config)
      download.download
    else
      download = MangaDownloader.new(config)
      download.download
    end
  }
end
