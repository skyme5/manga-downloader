#!/usr/bin/ruby

require 'mechanize'
require 'nokogiri'
require 'open-uri'
require 'json'

require 'http'
require 'to_duration'
require 'tty-logger'

require_relative 'templates'

class MangaDownloader
  def initialize(config)
    @start = Time.now
    @logger = TTY::Logger.new do |config|
      config.level = :debug # or "INFO" or TTY::Logger::INFO_LEVEL
    end
    @prefix = 'z:/Books/Manga'
    @manga_config = config
    @download_list = []
    @queue = Queue.new
    @threads = []
  end

  def manga_title
    @manga_config['title']
  end

  def manga_name
    @manga_config['name']
  end

  def manga_type
    @manga_config['ln'] ? 'Light Novel' : 'Manga'
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
    out = File.open(config_path, 'w')
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
    html = HTTP.get(url, {
			headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.61 Safari/537.36'}
		}).to_s
    Nokogiri::HTML(
      html
      .gsub('<!--', '')
      .gsub('-->', '')
      .gsub('data-src=', 'src=')
    )
  end

  def chapter_exist(chapter)
    itexist =
      @manga_config['chapters']['items'].select do |e|
        e['url'] == chapter[:url]
      end

    itexist.length > 0
  end

  def config_push_chapter(chapter)
    if !chapter_exist(chapter)
      @manga_config['chapters']['items'] << chapter
      @manga_config['chapters']['count'] =
        @manga_config['chapters']['items'].length
    end
  end

  def fetch_manga_page
    doc = page_fetch(@manga_config['url'])
    chapters = doc.css(@manga_config['selector']['chapter']).to_a.reverse
    log_i("Found #{chapters.length} chapters")
    index = @manga_config['chapters']['index_start'].to_i
    chapters.map! do |e|
      data = {
        chapter: index,
        title: e['title'],
        url: e['href'].gsub('?style=paged', '?style=list')
      }
      index += 1
      data
    end
  end

  def fetch_chapter_page(url)
    doc = page_fetch(url)
    img = doc.css(@manga_config['selector']['page']).to_a
    img = doc.css(@manga_config['selector']['page1']).to_a if img.length < 3

    index = 0
    images = []
    img.each do |e|
      index += 1

      images << { number: index, url: e['src'] }
    end

    images
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

    out = File.open('urls.txt', 'a')
    out.puts download.join("\n")
    out.close

    log('Downloading images')
    if !list.empty?
      system(
        'aria2c --check-certificate=false --auto-file-renaming=false --continue=true -j8 -x16 -i urls.txt'
      )
    end
  end

  def file_flush_data(filename, data, write_type = 'w')
    out = File.open(File.join(@prefix, filename), write_type)
    out.puts data
    out.close
  end

  def pad_num(num)
    num.to_s.rjust(4, '0')
  end

  def page_html_generate(images, chapter, chapter_total)
    chapter_num = chapter['chapter']

    buttons = []
    if chapter_num > @manga_config['chapters']['index_start']
      buttons <<
        "<a class='prev' href='Chapter #{
          pad_num(chapter_num - 1)
        }.html'><div>&#9664;</div></a>"
    end
    buttons <<
      "<a class='next' href='Chapter #{
        pad_num(chapter_num + 1)
      }.html'><div>&#9654;</div></a>"

    img =
      images.map do |e|
        "<img src='./Chapter #{pad_num(chapter_num)}/Page #{
          e[:number]
        }.jpg'></img>"
      end

    document = TEMPLATE_HTML.gsub('{{chapter_index}}', chapter_num.to_s)
    document = document.gsub('{{mange_title}}', manga_title)
    document = document.gsub('{{button}}', buttons.join("\n"))
    document = document.gsub('{{body}}', img.join("\n"))

    Dir.mkdir(manga_dir) unless Dir.exist?(manga_dir)

    html_page =
      "#{manga_name}/#{manga_type}/Chapter #{pad_num(chapter_num)}.html"
    file_flush_data(html_page, document, 'w') unless File.exist?(html_page)
  end

  def parallel
    1.times do
      @threads <<
        Thread.new do
          # loop until there are no more things to do
          until @queue.empty?
            # pop with the non-blocking flag set, this raises
            # an exception if the queue is empty, in which case
            # work_unit will be set to nil
            work_unit =
              begin
                @queue.pop(true)
              rescue StandardError
                nil
              end
            if work_unit
              chapter = work_unit[:data]
              total = work_unit[:total]
              chapter_url = chapter[:url]
              chapter_images = fetch_chapter_page(chapter_url)
              log(
                "Chapter #{chapter[:chapter]} has #{
                  chapter_images.length
                } pages"
              )

              chapter_item = {
                'url' => chapter[:url],
                'chapter' => chapter[:chapter],
                'title' => chapter[:title],
                'items' => chapter_images,
                'count' => chapter_images.length
              }

              config_push_chapter(chapter_item)

              chapter_images.each do |image|
                @download_list <<
                  {
                    'directory' =>
                      "#{@prefix}/#{manga_name}/#{manga_type}/Chapter #{
                        pad_num(chapter[:chapter])
                      }",
                    'filename' => "Page #{image[:number]}.jpg",
                    'url' => image[:url]
                  }
              end

              page_html_generate(chapter_images, chapter_item, total)
            end
          end # when there is no more work, the thread will stop
        end
    end

    # wait until all threads have completed processing
    @threads.each(&:join)
  end

  def download
    log('Getting manga page')

    chapters = fetch_manga_page

    @manga_config['chapters']['index_end'] = chapters.length

    if chapters.length > @manga_config['chapters']['count']

    else
      log('No new chapters found')
      return false
    end

    chapters.reject! { |e| chapter_exist(e) }
    chapters.each { |e| @queue << { data: e, total: chapters.length } }

    parallel

    log("Found #{@download_list.length} images for download")

    config_save
    save_links_aria2c(@download_list)

    log("Finish downloading in #{(Time.now - @start)}s")

    true
  end
end
