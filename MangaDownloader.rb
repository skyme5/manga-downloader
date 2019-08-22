#!/usr/bin/ruby
# @Author: Aakash Gajjar
# @Date:   2019-08-03 20:14:06
# @Last Modified by:   Sky
# @Last Modified time: 2019-08-22 13:20:42

require 'mechanize'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'to_duration'
require 'ColoredLogger'

require_relative 'templates'

class MangaDownloader
  def initialize(manga_title = '')
    @start = Time.now
    @prefix = "Z:/Books/Manga"
    @manga_title = manga_title
    @manga_config = config_get
    @download_list = []
    @logger = ColoredLogger.new(STDOUT)
  end

  def manga_title
    @manga_title.gsub(/[\\\/\:\*\?\"\<\>\|]+/, ' - ')
    .gsub(/[ ]{2,}/, ' ')
  end

  def config_filename
    manga_title + ".json"
  end

  def config_dir
    File.join(@prefix, manga_title)
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

  def config_get
    path = config_path
    if File.exist?(path) && !@manga_title.empty?
      return JSON.parse(File.read(path))
    else
      config = config_create_new
      @manga_title = config["title"]
      return config
    end
  end

  def config_save
    Dir.mkdir(config_dir) if !Dir.exist?(config_dir)
    out = File.open(config_path, "w")
    out.puts @manga_config.to_json
    out.close
  end

  def log_i(txt)
    @logger.info(@manga_title, txt)
  end

  def log(txt)
    @logger.debug(@manga_title, txt)
  end

  def page_fetch(url)
    Nokogiri::HTML.parse(open(url))
  end

  def chapter_exist(chapter)
    itexist = @manga_config["chapters"]["items"].select{
      |e|
      e["url"] == chapter[:url]
    }

    itexist.length > 0
  end

  def config_push_chapter(chapter)
    if chapter_exist(chapter)
    else
      @manga_config["chapters"]["items"] << chapter
      @manga_config["chapters"]["count"] = @manga_config["chapters"]["items"].length
    end
  end

  def fetch_manga_page
    doc = page_fetch(@manga_config["url"])
    chapters = doc.css(@manga_config["selector"]["chapter"]).to_a.reverse
    log_i("Found #{chapters.length} chapters")
    _index = @manga_config["chapters"]["index_start"].to_i
    chapters.map!{
      |e|
      data = {
        :chapter => _index,
        :title => e["title"],
        :url => e["href"].gsub("?style=paged", "?style=list")
      }
      _index = _index + 1
      data
    }
  end

  def fetch_chapter_page(url)
    doc = page_fetch(url)
    img = doc.css(@manga_config["selector"]["page"]).to_a

    _index = 0
    images = []
    img.each{
      |e|
      _index = _index + 1

      images << {
        :number => _index,
        :url => e["src"]
      }
    }

    images
  end

  def save_links_aria2c(list)
    download = list.flatten.map!{
      |url|
      [
        url["url"],
        "    dir=" + url["directory"],
        "    out=" + url["filename"].split("&")[0]
      ].join("\n")
    }

    out = File.open("urls.txt", "w")
    out.puts download.join("\n")
    out.close

    log("Downloading images")
    system("aria2c --auto-file-renaming=false --continue=true -q -i urls.txt") if !list.empty?
  end

  def file_flush_data(filename, data, write_type = "w")
    out = File.open(File.join(@prefix, filename), write_type)
    out.puts data
    out.close
  end

  def page_html_generate(images, chapter, chapter_total)
    chapter_num = chapter["chapter"]

    buttons = []
    buttons << "<a class='prev' href='Chapter #{chapter_num - 1}.html'><div>&#9664;</div></a>" if chapter_num > @manga_config["chapters"]["index_start"]
    buttons << "<a class='next' href='Chapter #{chapter_num + 1}.html'><div>&#9654;</div></a>"

    img = images.map {
      |e|
      "<img src='./Chapter #{chapter_num}/Page #{e[:number]}.jpg'></img>"
    }

    document = TEMPLATE_HTML.gsub("{{chapter_index}}", chapter_num.to_s)
    document = document.gsub("{{mange_title}}", @manga_title)
    document = document.gsub("{{button}}", buttons.join("\n"))
    document = document.gsub("{{body}}", img.join("\n"))

    Dir.mkdir(manga_dir) if !Dir.exist?(manga_dir)

    html_page = "#{manga_title}/Chapter #{chapter_num}.html"
    file_flush_data(html_page, document, "w") if !File.exist?(html_page)
  end

  def download
    log("Getting manga page")

    chapters = fetch_manga_page

    @manga_config["chapters"]["index_end"] = chapters.length

    if chapters.length > @manga_config["chapters"]["count"]
    else
      log("No new chapters found")
    end

    for chapter in chapters
      next if chapter_exist(chapter)

      chapter_url = chapter[:url]
      chapter_images = fetch_chapter_page(chapter_url)
      log("Chapter #{chapter[:chapter]} has #{chapter_images.length} pages")

      chapter_item = {
        "url" => chapter[:url],
        "chapter" => chapter[:chapter],
        "title" => chapter[:title],
        "items" => chapter_images,
        "count" => chapter_images.length
      }

      config_push_chapter(chapter_item)
      config_save

      for image in chapter_images
        @download_list << {
          "directory" => "#{@prefix}/#{manga_title}/Chapter #{chapter[:chapter]}",
          "filename" => "Page #{image[:number]}.jpg",
          "url" => image[:url]
        }
      end

      page_html_generate(chapter_images, chapter_item, chapters.length)
    end

    log("Found #{@download_list.length} images for download")

    config_save
    save_links_aria2c(@download_list)

    log("Finish downloading in #{(Time.now - @start).to_duration}")
  end
end
