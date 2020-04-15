#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'json'

def manga_dir
  'z:/Books/Manga'
end

def pad_num(num)
  num.to_s.rjust(4, '0')
end

def save_links_aria2c(list)
  download =
    list.flatten.map! do |url|
      [
        url['url'],
        '    dir=' + url['directory'],
        '    out=' + url['filename'].split('&')[0]
      ].join("\n")
    end

  out = File.open('urls.txt', 'w')
  out.puts download.join("\n")
  out.close

  unless list.empty?
    system(
      'aria2c --check-certificate=false --auto-file-renaming=false --continue=true -i urls.txt'
    )
  end
end

def download(config, _config_path)
  download_list = []
  manga_name = config['name']
  puts manga_name
  manga_type = config['ln'] ? 'Light Novel' : 'Manga'
  config['chapters']['items'].each do |chapter|
    chapter['items'].each do |image|
      download_list <<
        {
          'directory' =>
            "#{manga_dir}/#{manga_name}/#{manga_type}/Chapter #{pad_num(chapter["chapter"])}",
          'filename' => "Page #{image["number"]}.jpg",
          'url' => image["url"]
        }
    end
  end
  save_links_aria2c(download_list)
  exit
end

manga =
  Dir.entries(manga_dir)[2..-1].select do |e|
    File.directory?(File.join(manga_dir, e))
  end

manga.each do |m|
  config_path = File.join(manga_dir, m, 'Manga', m + ' - Manga.json')

  next if !File.exist?(config_path)
  config = JSON.parse(File.read(config_path))

  if !config['ln']
    download(config, config_path)
    system('rm urls.txt') if File.exist?('urls.txt')
  end
end
