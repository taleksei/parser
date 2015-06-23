#!/bin/env ruby
# encoding: utf-8

module Helper

  def save_array_in_file(file, array)
    #File.open(file, 'w') do |f|
    #  array.each { |item| f << item }
    #end
    File.open(file, 'w') do |file|
      array.each { |item| file << item.to_s + "\n" }
    end
  end
end