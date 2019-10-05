#!/usr/bin/ruby
# @Author: Aakash Gajjar
# @Date:   2019-08-03 20:14:06
# @Last Modified by:   Sky
# @Last Modified time: 2019-10-05 12:54:30

require 'json'

class MangaConfig
  def initialize
    @prefix = "Z:/Books/Manga"
    @manga_config = config_create_new
    config_save
  end

  def get
    return @manga_config
  end

  def config_save
    Dir.mkdir(config_dir) if !Dir.exist?(config_dir)
    out = File.open(config_path, "w")
    out.puts @manga_config.to_json
    out.close
  end

  def normalize(title)
    title.gsub(/[\\\/\:\*\?\"\<\>\|]+/, ' - ')
    .gsub(/\r\n/im, ' ')
    .gsub(/[ ]{2,}/im, ' ')
  end

  def manga_name
    @manga_config["name"]
  end

  def config_filename
    manga_name + ".json"
  end

  def config_dir
    File.join(@prefix, manga_name)
  end

  def manga_dir
    config_dir
  end

  def config_path
    File.join(config_dir, config_filename)
  end

  def config_create_new
    puts "Enter title of mange: "
    title = STDIN.gets.chomp
    while title.empty?
      puts "Enter title of mange: "
      title = STDIN.gets.chomp
    end

    puts "Enter url of mange: "
    url = STDIN.gets.chomp
    while url.empty?
      puts "Enter url of mange: "
      url = STDIN.gets.chomp
    end

    if url.include?("www.readlightnovel.org")
      ln = true
    else
      puts "Is this Light Novel? [y/n]: "
      ln = STDIN.gets.chomp
      ln = !ln.empty? ? ln.downcase.include?("y") : false
    end
    puts "This is a #{ln ? "Light Novel" : "Manga"}"

    puts "Enter index_start[default = 1]: "
    input = STDIN.gets.chomp
    index_start = input.empty? ? 1 : input.to_i

    pre_selected = ln ? "#accordion .tab-content li a" : ".chapter-list a"
    puts "Enter Selector for chapter[default = '#{pre_selected }']: "
    input = STDIN.gets.chomp
    chapter_selector = ln ? (input.empty? ? "#accordion .tab-content li a" : input) : (input.empty? ? ".chapter-list a" : input)

    pre_selected = ln ? ".chapter-content3 .desc" : ".vung-doc img"
    puts "Enter Selector for page[default = '#{pre_selected }']: "
    input = STDIN.gets.chomp
    page_selector = ln ? (input.empty? ? ".chapter-content3 .desc" : input) : (input.empty? ? ".vung-doc img" : input)

    #puts "Enter Selector for cover[default = '.manga-info-pic img']: "
    #input = STDIN.gets.chomp
    #cover_selector = input.empty? ? ".manga-info-pic img" : input

    return {
      "title" => title.gsub(/\r\n/im, ' ').gsub(/[ ]{2,}/im, ' '),
      "url" => url,
      "ln" => ln,
      "name" => [normalize(title), ln ? " - Light Novel" : ""].join(""),
      "chapters" => {
        "index_start" => index_start,
        "index_end" => 0,
        "count" => 0,
        "items" => []
      },
      "selector" => {
        "chapter" => chapter_selector,
        "page" => page_selector
      }
    }
  end
end
