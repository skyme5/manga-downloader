#!/usr/bin/ruby
# @Author: Aakash Gajjar
# @Date:   2019-08-03 20:14:06
# @Last Modified by:   Sky
# @Last Modified time: 2019-10-05 12:52:42

require 'mechanize'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'to_duration'
require 'ColoredLogger'

require_relative 'templates'

class LNDownloader
  def initialize(config)
    @start = Time.now
    @logger = ColoredLogger.new(STDOUT)
    @prefix = "Z:/Books/Manga"
    @manga_config = config
    @download_list = []
  end

  def manga_title
    @manga_config["title"]
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

  def config_save
    Dir.mkdir(config_dir) if !Dir.exist?(config_dir)
    out = File.open(config_path, "w")
    out.puts @manga_config.to_json
    out.close
  end

  def log_i(txt)
    @logger.info(manga_name, txt)
  end

  def log(txt)
    @logger.debug(manga_name, txt)
  end

  def page_fetch(url)
    log(url)
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
    if !chapter_exist(chapter)
      @manga_config["chapters"]["items"] << chapter
      @manga_config["chapters"]["count"] = @manga_config["chapters"]["items"].length
    end
  end

  def fetch_manga_page
    doc = page_fetch(@manga_config["url"])
    chapters = doc.css(@manga_config["selector"]["chapter"]).to_a
    log_i("Found #{chapters.length} chapters")
    _index = @manga_config["chapters"]["index_start"].to_i
    chapters.map!{
      |e|
      data = {
        :chapter => _index,
        :title => e.text,
        :url => e["href"]
      }
      _index = _index + 1
      data
    }
  end

  def fetch_chapter_page(url)
    doc = page_fetch(url)
    page = doc.css(@manga_config["selector"]["page"]).to_a

    page.each{
      |elm|
      elm.search('.//script').remove
    }

    page.map!{
      |e|
      e.to_s
    }
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

  def pad_num(num)
    num.to_s.rjust(4, "0")
  end

  def page_html_generate(content, chapter, chapter_total)
    chapter_num = chapter["chapter"]

    buttons = []
    buttons << "<a class='prev' href='Chapter #{pad_num(chapter_num - 1)}.html'><div>&#9664;</div></a>" if chapter_num > @manga_config["chapters"]["index_start"]
    buttons << "<a class='next' href='Chapter #{pad_num(chapter_num + 1)}.html'><div>&#9654;</div></a>"

    body = "<article>#{content.join("\n")}</article>"

    document = TEMPLATE_HTML.gsub("{{chapter_index}}", chapter_num.to_s)
    document = document.gsub("{{mange_title}}", manga_title)
    document = document.gsub("{{button}}", buttons.join("\n"))
    document = document.gsub("{{body}}", body)

    Dir.mkdir(manga_dir) if !Dir.exist?(manga_dir)

    html_page = "#{manga_name}/Chapter #{pad_num(chapter_num)}.html"
    file_flush_data(html_page, document, "w") if !File.exist?(html_page)
  end

  def page_json_generate(content, chapter, chapter_total)
    chapter_num = chapter["chapter"]

    document = content.to_json

    Dir.mkdir(manga_dir) if !Dir.exist?(manga_dir)

    html_page = "#{manga_name}/Chapter #{pad_num(chapter_num)}.json"
    file_flush_data(html_page, document, "w") if !File.exist?(html_page)
  end

  def download
    log("Getting manga page")

    chapters = fetch_manga_page

    @manga_config["chapters"]["index_end"] = chapters.length

    if chapters.length > @manga_config["chapters"]["count"]
    else
      log("No new chapters found")
      return false
    end

    for chapter in chapters
      next if chapter_exist(chapter)

      chapter_url = chapter[:url]
      chapter_content = fetch_chapter_page(chapter_url)

      chapter_item = {
        "url" => chapter[:url],
        "chapter" => chapter[:chapter],
        "title" => chapter[:title]
      }
      chapter_item_json = {
        "url" => chapter[:url],
        "chapter" => chapter[:chapter],
        "title" => chapter[:title],
        "items" => chapter_content
      }

      config_push_chapter(chapter_item)
      config_save

      page_html_generate(chapter_content, chapter_item, chapters.length)
      page_json_generate(chapter_item_json, chapter_item, chapters.length)
    end

    #log("Found #{@download_list.length} images for download")

    config_save
    # save_links_aria2c(@download_list)

    log("Finish downloading in #{(Time.now - @start).to_duration}")

    return true
  end
end
