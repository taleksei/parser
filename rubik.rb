#!/bin/env ruby
# encoding: utf-8

load 'helper.rb'
load 'group.rb'

class Rubik
  attr_accessor :link, :file, :rubik_array

  include Helper

  def initialize(link, file)
    @link, @file = link, file
    @rubik_array = load
  end

  def save
    doc = open(URI.encode(@link), 'r:windows-1251')
    result = doc.select { |l| l =~ /^dtree.*\.add(.*,??);/ }
    result.map! {|l| l.sub(/^dtree.*\.add\("/, '').sub(/","[^"]*",""\);$/, '').gsub(/\",\"/, "\t")}
    save_array_in_file(@file, result)
  end

  def load
    save unless File.exist?(@file)
    File.open(@file, 'r') do |f|
      array = []
      while (line = f.gets)
        array << Group.new(line.split("\t"))
      end
      array
    end
  end

  def load_group(id)
    @rubik_array.first {|group| group.id == id}
  end

  def rubik_array
    @rubik_array
  end

end
