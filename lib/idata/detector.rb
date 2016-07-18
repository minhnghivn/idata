require 'csv'

# Set UTF-8
Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

class Array
  def to_h
    h = {}
    self.each do |e|
      h[e.first] = e.last
    end
    return h
  end
end

module Idata
  class Detector
    DEFAULT_DELIMITER = ","
    COMMON_DELIMITERS = [DEFAULT_DELIMITER, "|", "\t", ";"]
    SAMPLE_SIZE = 100

    def initialize(file)
      @file = file
      @sample = `head -n #{SAMPLE_SIZE} #{@file}`.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      @sample_lines = @sample.split(/[\r\n]+/)
      @candidates = COMMON_DELIMITERS.map { |delim|
        [delim, @sample.scan(delim).count]
      }.to_h.select{|k,v| v > 0}
    end

    def find
      return DEFAULT_DELIMITER if @candidates.empty? # for example, file with only one header
      return find_same_occurence || find_valid || find_max_occurence || DEFAULT_DELIMITER
    end
    
    # just work
    def find_valid
      selected = @candidates.select { |delim, count|
        begin
          CSV.parse(@sample, col_sep: delim)
          true
        rescue Exception => ex
          false
        end
      }.keys

      return selected.first if selected.count == 1
      return DEFAULT_DELIMITER if selected.include?(DEFAULT_DELIMITER)
    end

    # high confident level
    def find_same_occurence
      selected = @candidates.select { |delim, count|
        begin
          CSV.parse(@sample, col_sep: delim).select{|e| !e.empty? }.map{|e| e.count}.uniq.count == 1
        rescue Exception => ex
          false
        end
      }.keys

      return selected.first if selected.count == 1
      return DEFAULT_DELIMITER if selected.include?(DEFAULT_DELIMITER)
    end
    
    # most occurence
    def find_max_occurence
      selected = @candidates.select{|k,v| v == @candidates.sort_by(&:last).last }.keys

      return selected.first if selected.count == 1
      return DEFAULT_DELIMITER if selected.include?(DEFAULT_DELIMITER)
    end
  end
end

