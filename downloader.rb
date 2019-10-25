#!/usr/bin/ruby

require 'optparse'
require 'json'

require_relative 'MangaConfig'
require_relative 'MangaDownloader'
require_relative 'LNDownloader'

MANGA_DIR = "Z:/Books/Manga"

$messages = []
def download(config)
  if config["ln"]
    download = LNDownloader.new(config)

    if download.download
      $messages << "Downloaded [#{config["title"]}]"
    end
  else
    download = MangaDownloader.new(config)

    if download.download
      $messages << "Downloaded [#{config["title"]}]"
    end
  end
end

if ARGV.length > 0
  config = MangaConfig.new()
  download(config.get)
else
  manga = Dir.entries(MANGA_DIR)[2..-1].select { |e|
    File.directory?(File.join(MANGA_DIR, e))
  }

  manga.each { |m|
    config_path = File.join(MANGA_DIR, m, "Manga", m + " - Manga.json")
    if File.exist?(config_path)
      config = JSON.parse(File.read(config_path))
      download(config)
    end

    config_path = File.join(MANGA_DIR, m, "Light Novel", m + " - Light Novel.json")
    if File.exist?(config_path)
      config = JSON.parse(File.read(config_path))
      download(config)
    end
  }
end

puts $messages if !$messages.empty?
