#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'json'

require_relative 'MangaConfig'
require_relative 'MangaDownloader'
require_relative 'LNDownloader'

MANGA_DIR = 'z:/Books/Manga'
SELECTOR_CONFIG = JSON.parse(File.read(File.join(__dir__, 'config.json')))

$messages = []
def update_selectors(config)
  config['selector'] = SELECTOR_CONFIG[URI(config['url']).host]
  config
end

def download(config, _config_path)
  config = update_selectors(config)

  if config['ln']
    download = LNDownloader.new(config)
  else
    download = MangaDownloader.new(config)
  end
  system('rm urls.txt') if File.exist?('urls.txt')
  $messages << "Downloaded [#{config['title']}]" if download.download
end

def download_manga(title)
  [
    File.join(MANGA_DIR, title, 'Manga', title + ' - Manga.json'),
    File.join(
      MANGA_DIR,
      title,
      'Light Novel - WEB',
      title + ' - Light Novel.json'
    )
  ].each do |config_path|
    if File.exist?(config_path)
      config = JSON.parse(File.read(config_path))
      download(config, config_path)
    end
  end
end

if ARGV.empty?
  while true
    config = MangaConfig.new
    download(config.get, config.config_path)
  end
elsif ARGV.include? '-u'
  manga =
    Dir.entries(MANGA_DIR)[2..-1].select do |e|
      File.directory?(File.join(MANGA_DIR, e))
    end

  manga.each do |title|
    download_manga(title)
  end
elsif ARGV.include? '-d'
  title = ARGV.last
  download_manga(title)
end

puts $messages unless $messages.empty?
