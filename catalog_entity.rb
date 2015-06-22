#!/bin/env ruby
# encoding: utf-8

class Catalog_entity
  attr_accessor :type, :name, :group, :image, :id

  def initialize(params)
    @type, @name, @group, @image, @id = params
  end

  def to_s
    "#{@type}\t#{@name}\t#{@group}\t#{@image}\t#{@id}"
  end
end