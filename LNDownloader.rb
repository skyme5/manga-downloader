#!/usr/bin/ruby

require 'mechanize'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'thread'

require 'http'
require 'to_duration'
require 'tty-logger'

require_relative 'templates'

class LNDownloader
  def initialize(config)
    @start = Time.now
    @logger = TTY::Logger.new do |config|
      config.level = :debug # or "INFO" or TTY::Logger::INFO_LEVEL
    end
    @prefix = "z:/Books/Manga"
    @manga_config = config
    @download_list = []
    @queue = Queue.new
    @threads = []
  end

  def manga_title
    @manga_config["title"]
  end

  def manga_name
    @manga_config["name"]
  end

  def manga_type
    @manga_config["ln"] ? "Light Novel" : "Manga"
  end

  def config_filename
    manga_name + " - #{manga_type}.json"
  end

  def config_dir
    File.join(@prefix, manga_name, manga_type)
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
    Nokogiri::HTML.parse(HTTP.get(url).to_s)
  end

  def chapter_exist(chapter)
    itexist = @manga_config["chapters"]["items"].select { |e|
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
    chapters.map! { |e|
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

    page.each { |elm|
      elm.search('.//script').remove
    }

    page.map! { |e|
      e.to_s
    }
  end

  def save_links_aria2c(list)
    download = list.flatten.map! { |url|
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

    html_page = "#{manga_name}//#{manga_type}/Chapter #{pad_num(chapter_num)}.html"
    file_flush_data(html_page, document, "w") if !File.exist?(html_page)
  end

  def page_json_generate(content, chapter, chapter_total)
    chapter_num = chapter["chapter"]

    document = content.to_json

    Dir.mkdir(manga_dir) if !Dir.exist?(manga_dir)

    html_page = "#{manga_name}/#{manga_type}/Chapter #{pad_num(chapter_num)}.json"
    file_flush_data(html_page, document, "w") if !File.exist?(html_page)
  end

  def parallel
    4.times do
      @threads << Thread.new do
        # loop until there are no more things to do
        until @queue.empty?
          # pop with the non-blocking flag set, this raises
          # an exception if the queue is empty, in which case
          # work_unit will be set to nil
          work_unit = @queue.pop(true) rescue nil
          if work_unit
            chapter = work_unit[:data]
            total = work_unit[:total]
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

            page_html_generate(chapter_content, chapter_item, total)
            page_json_generate(chapter_item_json, chapter_item, total)
          end
        end
        # when there is no more work, the thread will stop
      end
    end

    # wait until all threads have completed processing
    @threads.each { |t| t.join }
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

    chapters.select! { |e| !chapter_exist(e) }
    chapters.each { |e| @queue << { data: e, total: chapters.length } }

    parallel

    config_save
    log("Finish downloading in #{(Time.now - @start)}s")

    return true
  end
end
