#!/bin/env ruby
# encoding: utf-8

require 'open-uri'
require 'mechanize'
require 'fileutils'
load 'rubik.rb'
load 'catalog_entity.rb'

CATALOG_LINK = 'http://prostoudobno.ru/Интернет/Доставка'
ROOT_LINK = 'http://prostoudobno.ru'
IMAGES_CATALOG = 'images'
RUBIK_FILE_PATH = 'rubik.txt'
CATALOG_FILE_PATH = 'catalog.txt'
RECORDS = 1000

class Parser

  def initialize(root_link, rubik_file_path)
    @buffer = []
    @loaded = []
    @rubik = Rubik.new(root_link, rubik_file_path)
    @buffer_product_count = 0
    @loaded_product_count = 0
    @addition_product_count = 0
    @head_group_count = 0
    load_catalog(CATALOG_FILE_PATH)
  end

  def load_catalog(file)
    if File.exist?(file)
      File.open(file, 'r') do |f|
        while (line = f.gets)
          @loaded << Catalog_entity.new(line.gsub("\n",'').split("\t"))
        end
        @loaded_product_count = @loaded.select { |i| i.type == 'product' }.count
        puts "Previously loaded #{@loaded_product_count} products"
      end
    end
  end

  def parse_catalog
    parse_group(@rubik.load_group('0'))
    save_to_file(CATALOG_FILE_PATH)
    print_statistic
  end

  def parse_group(rubik_group)

    return if check_loaded_count?

    catalog_group = add_group_in_category(rubik_group)
    subgroups = @rubik.rubik_array.select {|item| item.parent_id == rubik_group.id }
    if subgroups.count > 0
      # на тесте использовал все группы, кроме первой(в ней много товаров, долгий тест)
      subgroups.each { |subgroup| parse_group(subgroup) }# unless subgroup.id == '1' }
    else
      link = ROOT_LINK + rubik_group.url
      puts "Loading... #{rubik_group.name}"

      count_before = @buffer_product_count

      FileUtils.mkdir_p IMAGES_CATALOG
      #функция URI.encode(link) добавляет в конец строки лишние 4 символа
      search_products(URI.encode(link)[0..-4], catalog_group)

      puts " loaded #{@buffer_product_count - count_before} products"

    end
  #rescue => exception
  #  puts "Error! #{exception.inspect}"
  end

  def search_products(link, catalog_group)

    #page = Nokogiri::HTML(open(link).read)
    mechanize = Mechanize.new
    page = mechanize.get(link)

    page.search('.browseProductContainer').each do |product_node|
      return if check_loaded_count?
      product = Catalog_entity.new(['product',
        product_node.search('.productname a').first.content,
        catalog_group.name,
        '',
        product_node.at('input[name = "product_id"]')['value']])

      unless @loaded.find { |item| item.id == product.id }
        product_image = product_node.search('.thumb_image a img').first
        unless product_image['src'][-12..-1] == '/default.jpg'
          image_file_name = get_random_file_name(IMAGES_CATALOG, product_image['src'][-4..-1])
          open(product_image['src']) do |img|
            File.open(image_file_name,"wb") { |f| f << img.read }
          end
        end
        product.image = image_file_name
        add_product_in_category(product, catalog_group)
      end

    end

    link_to_next_page = page.link_with(text: /.*Следующая.*/)
    if link_to_next_page && !check_loaded_count?
      search_products(ROOT_LINK + URI.encode(link_to_next_page.href), catalog_group)
    end
  end

  def add_product_in_category(product, catalog_group)    
    group_index = @loaded.index(catalog_group) 
    @loaded.insert(group_index + 1, product)
    @buffer << product
    @buffer_product_count += 1
    @loaded_product_count += 1
  end

  def add_group_in_category(rubik_group)   
    group = @loaded.find {|item| item.id == rubik_group.id}
    unless group
      type = case rubik_group.parent_id
        when '-1'
          'root'
        when '0'
          @head_group_count += 1
          'group'
        else
          'subgroup'
        end
      group = Catalog_entity.new([type, rubik_group.name, '', '', rubik_group.id])
      @loaded << group
      @buffer << group
    end 
    group
  end

  def print_statistic
    puts 'Summary ' + '*'*50
    
    puts "Loaded just now (product/categories): #{@buffer_product_count}/#{group_count(@buffer)}"
    
    puts 'Product count in head group: '
    count_report

    image_statistic
    puts '*'*58
  end

  def save_to_file(file_name)
    File.open(file_name, 'w') do |file|
      @loaded.each { |item| file << item.to_s + "\n" }
    end
  end

  def get_random_file_name(directory, ext)
    file_name = directory + '/' + [*('a'..'z'),*('0'..'9')].shuffle[0,10].join + ext
    get_random_file_name(directory, ext) if File.exist?(file_name)
    file_name
  end

  def group_count(array)
    array.select { |i| i.type != 'product' }.count
  end

  def count_report
    count = 0
    @loaded.each do |item| 
      if item.type == 'group'
        print ", count: #{count}" if count > 0
        puts ", #{((count/@loaded_product_count.to_f)*100).round}% of all"  if count > 0
        print "  group: #{item.name}"
        count = 0
      else
        count += 1 if item.type == 'product'
      end
    end
    print ", count: #{count}"
    puts ", #{((count/@loaded_product_count.to_f)*100).round}% of all"
    puts "Product count: #{@loaded_product_count}"
  end

  def check_loaded_count?
    @addition_product_count += 1 if @head_group_count > 1
    @buffer_product_count >= RECORDS &&
      @head_group_count > 1 &&
        @addition_product_count >= 100
  end

  def human_size(number)
    count = 0
    while  number >= 1024 and count < 4
      number /= 1024.0
      count += 1
    end
    format("%.2f",number) + %w(B KB MB GB TB)[count]
  end

  def image_statistic
    with_image_count = @loaded.select { |i| i.type == 'product' && !i.image.nil? }.count
    with_image = ((with_image_count/@loaded_product_count.to_f) * 100).round
    puts "With image: #{with_image}%, (#{with_image_count} из #{@loaded_product_count})"
    sum_size = 0
    product_with_image_count = 0
    max_size = 0
    max_size_image = ''
    min_size = 1000000000
    min_size_image = ''
    @loaded.select { |i| i.type == 'product' }.each do |item|
      if item.image != nil && File.exists?(item.image) && File.size(item.image) > max_size
        max_size = File.size(item.image)
        max_size_image = item.image
      end
      if item.image != nil && File.exists?(item.image) && File.size(item.image) < min_size
        min_size = File.size(item.image)
        min_size_image = item.image
      end
      if item.image != nil && File.exists?(item.image)
        sum_size += File.size(item.image)
        product_with_image_count += 1
      end
    end

    avg_size = sum_size.nil? ? 0 : ((sum_size/product_with_image_count.to_f)).round
    puts "Average image size: #{human_size(avg_size)}"
    puts "Maximum image size: #{human_size(max_size)}, #{max_size_image}"
    puts "Minimum image size: #{human_size(min_size)}, #{min_size_image}"
  end
end

parser = Parser.new(CATALOG_LINK, RUBIK_FILE_PATH)
parser.parse_catalog


