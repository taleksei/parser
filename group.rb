#!/bin/env ruby
# encoding: utf-8

class Group
  attr_accessor :id, :parent_id, :name, :url

  def initialize(params)
    @id, @parent_id, @name, @url = params
  end

  def to_s
    "#{@id}\t#{@parent_id}\t#{@name}\t#{@url}"
  end
end