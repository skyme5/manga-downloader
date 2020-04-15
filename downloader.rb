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

if ARGV.length.positive?
  while true
    config = MangaConfig.new
    download(config.get, config.config_path)
    puts 'Download new ? [y/n]'
    exit unless STDIN.gets.chomp.include? 'y'
  end
else
  manga =
    Dir.entries(MANGA_DIR)[2..-1].select do |e|
      File.directory?(File.join(MANGA_DIR, e))
    end

  manga.each do |m|
    [
      File.join(MANGA_DIR, m, 'Manga', m + ' - Manga.json'),
      File.join(MANGA_DIR, m, 'Light Novel', m + ' - Light Novel.json')
    ].each do |config_path|
      if File.exist?(config_path)
        config = JSON.parse(File.read(config_path))
        download(config, config_path)
      end
    end
  end
end

puts $messages unless $messages.empty?
