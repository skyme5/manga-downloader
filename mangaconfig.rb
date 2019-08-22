#!/usr/bin/ruby
# @Author: Aakash Gajjar
# @Date:   2019-08-03 20:14:06
# @Last Modified by:   Sky
# @Last Modified time: 2019-08-22 13:24:24

require 'json'

class MangaConfig
  def initialize()
    @prefix = "D:/temp"
    @manga_config = config_get
    save_config
  end

  def config_save
    Dir.mkdir(config_dir) if !Dir.exist?(config_dir)
    out = File.open(config_path, "w")
    out.puts @manga_config.to_json
    out.close
  end

  def manga_name(title)
    @manga_config["title"].gsub(/[\\\/\:\*\?\"\<\>\|]+/, ' - ')
                          .gsub(/[ ]{2,}/, ' ')
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

    puts "Is this Light Novel? [y/n]: "
    ln = STDIN.gets.chomp
    ln = ln.empty?

    puts "Enter index_start[default = 1]: "
    input = STDIN.gets.chomp
    index_start = input.empty? ? 1 : input.to_i

    puts "Enter Selector for chapter[default = '.chapter-list a']: "
    input = STDIN.gets.chomp
    chapter_selector = input.empty? ? ".chapter-list a" : input

    puts "Enter Selector for page[default = '.vung-doc img']: "
    input = STDIN.gets.chomp
    page_selector = input.empty? ? ".vung-doc img" : input

    #puts "Enter Selector for cover[default = '.manga-info-pic img']: "
    #input = STDIN.gets.chomp
    #cover_selector = input.empty? ? ".manga-info-pic img" : input

    return {
      "title" => title,
      "url" => url,
      "ln" => ln,
      "name" => [title, ln ? " - Light Novel" : ""].join(""),
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
