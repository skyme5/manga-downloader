#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

class MangaConfig
  def initialize
    @prefix = 'z:/Books/Manga'
    @selectors = JSON.parse(File.read(File.join(__dir__, 'config.json')))
    @manga_config = config_create_new
    config_save
  end

  def get
    @manga_config
  end

  def config_save
    FileUtils.mkpath(config_dir) unless Dir.exist?(config_dir)
    out = File.open(config_path, 'w')
    out.puts @manga_config.to_json
    out.close
  end

  def normalize(title)
    title.gsub(%r{[\\\/\:\*\?\"\<\>\|]+}, ' - ').gsub(/\r\n/im, ' ').gsub(
      /[ ]{2,}/im,
      ' '
    )
  end

  def manga_name
    @manga_config['name']
  end

  def manga_type
    @manga_config['ln'] ? 'Light Novel' : 'Manga'
  end

  def manga_folder
    @manga_config['ln'] ? 'Light Novel - WEB' : 'Manga'
  end

  def config_filename
    manga_name + " - #{manga_type}.json"
  end

  def config_dir
    File.join(@prefix, manga_name, manga_folder)
  end

  def manga_dir
    config_dir
  end

  def config_path
    File.join(config_dir, config_filename)
  end

  def config_create_new
    puts 'Enter title of manga: '
    title = STDIN.gets.chomp
    while title.empty?
      puts 'Enter title of manga: '
      title = STDIN.gets.chomp
    end

    puts 'Enter url of manga: '
    url = STDIN.gets.chomp
    while url.empty?
      puts 'Enter url of manga: '
      url = STDIN.gets.chomp
    end

    if @selectors.key?(URI(url).host)
      ln = @selectors[URI(url).host]['ln']
    else
      puts 'Is this Light Novel? [y/n, default = n]: '
      ln = STDIN.gets.chomp
      ln = !ln.empty? ? ln.downcase.include?('y') : false
    end
    puts "This is a #{ln ? 'Light Novel' : 'Manga'}"

    puts 'Enter index_start[default = 1]: '
    input = STDIN.gets.chomp
    index_start = input.empty? ? 1 : input.to_i

    pre_selected = @selectors[URI(url).host]['chapter']
    puts "Enter Selector for chapter[default = '#{pre_selected}']: "
    input = STDIN.gets.chomp
    chapter_selector = input.empty? ? pre_selected : input

    pre_selected = @selectors[URI(url).host]['page']
    puts "Enter Selector for page[default = '#{pre_selected}']: "
    input = STDIN.gets.chomp
    page_selector = input.empty? ? pre_selected : input

    # puts "Enter Selector for cover[default = '.manga-info-pic img']: "
    # input = STDIN.gets.chomp
    # cover_selector = input.empty? ? ".manga-info-pic img" : input

    {
      'host' => URI(url).host,
      'title' => title.gsub(/\r\n/im, ' ').gsub(/[ ]{2,}/im, ' '),
      'url' => url,
      'ln' => ln,
      'name' => normalize(title),
      'chapters' => {
        'index_start' => index_start,
        'index_end' => 0,
        'count' => 0,
        'items' => []
      },
      'selector' => { 'chapter' => chapter_selector, 'page' => page_selector }
    }
  end
end
