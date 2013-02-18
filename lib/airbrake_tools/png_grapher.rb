require 'chunky_png'

module AirbrakeTools
  module PngGrapher
    BitFont = {
      " " => [ 5, 0b000000, 0b000000, 0b000000, 0b000000, 0b000000 ],
      "A" => [ 6, 0b001110, 0b010001, 0b011111, 0b010001, 0b010001 ],
      "B" => [ 6, 0b001111, 0b010001, 0b001111, 0b010001, 0b011111 ],
      "C" => [ 6, 0b011110, 0b000001, 0b000001, 0b000001, 0b011110 ],
      "D" => [ 6, 0b001111, 0b010001, 0b010001, 0b010001, 0b001111 ],
      "E" => [ 6, 0b011111, 0b000001, 0b000111, 0b000001, 0b011111 ],
      "F" => [ 6, 0b011111, 0b000001, 0b000111, 0b000001, 0b000001 ],
      "G" => [ 6, 0b011110, 0b000001, 0b011101, 0b010001, 0b011110 ],
      "H" => [ 6, 0b010001, 0b010001, 0b011111, 0b010001, 0b010001 ],
      "I" => [ 4, 0b000111, 0b000010, 0b000010, 0b000010, 0b000111 ],
      "J" => [ 6, 0b011100, 0b001000, 0b001000, 0b001001, 0b001111 ],
      "K" => [ 6, 0b010001, 0b001001, 0b000111, 0b001001, 0b010001 ],
      "L" => [ 6, 0b000001, 0b000001, 0b000001, 0b000001, 0b011111 ],
      "M" => [ 6, 0b001011, 0b010101, 0b010101, 0b010101, 0b010101 ],
      "N" => [ 6, 0b010001, 0b010011, 0b010101, 0b011001, 0b010001 ],
      "O" => [ 6, 0b001110, 0b010001, 0b010001, 0b010001, 0b001110 ],
      "P" => [ 6, 0b001111, 0b010001, 0b001111, 0b000001, 0b000001 ],
      "Q" => [ 6, 0b001110, 0b010001, 0b010001, 0b010101, 0b001110, 0b001000 ],
      "R" => [ 6, 0b001111, 0b010001, 0b011111, 0b001001, 0b010001 ],
      "S" => [ 6, 0b011110, 0b000001, 0b001110, 0b010000, 0b001111 ],
      "T" => [ 6, 0b011111, 0b000100, 0b000100, 0b000100, 0b000100 ],
      "U" => [ 6, 0b010001, 0b010001, 0b010001, 0b010001, 0b001110 ],
      "V" => [ 6, 0b010001, 0b010001, 0b001010, 0b001010, 0b000100 ],
      "W" => [ 6, 0b010101, 0b010101, 0b010101, 0b010101, 0b001010 ],
      "X" => [ 6, 0b010001, 0b001010, 0b000100, 0b001010, 0b010001 ],
      "Y" => [ 6, 0b010001, 0b001010, 0b000100, 0b000100, 0b000100 ],
      "Z" => [ 6, 0b011111, 0b001000, 0b000100, 0b000010, 0b011111 ],
      "0" => [ 6, 0b001110, 0b011001, 0b010101, 0b010011, 0b001110 ],
      "1" => [ 4, 0b000010, 0b000011, 0b000010, 0b000010, 0b000111 ],
      "2" => [ 6, 0b001111, 0b010000, 0b001110, 0b000001, 0b011111 ],
      "3" => [ 6, 0b011111, 0b010000, 0b011100, 0b010000, 0b011111 ],
      "4" => [ 6, 0b010001, 0b010001, 0b011111, 0b010000, 0b010000 ],
      "5" => [ 6, 0b011111, 0b000001, 0b011111, 0b010000, 0b011111 ],
      "6" => [ 6, 0b011111, 0b000001, 0b011111, 0b010001, 0b011111 ],
      "7" => [ 6, 0b011111, 0b010000, 0b010000, 0b010000, 0b010000 ],
      "8" => [ 6, 0b011111, 0b010001, 0b011111, 0b010001, 0b011111 ],
      "9" => [ 6, 0b011111, 0b010001, 0b011111, 0b010000, 0b010000 ],
      "." => [ 3, 0b000000, 0b000000, 0b000000, 0b000011, 0b000011 ],
      ":" => [ 5, 0b000000, 0b000110, 0b000000, 0b000110, 0b000000 ],
      "\\"=> [ 6, 0b000001, 0b000010, 0b000100, 0b001000, 0b010000 ],
      "/" => [ 6, 0b010000, 0b001000, 0b000100, 0b000010, 0b000001 ],
      "?" => [ 5, 0b001110, 0b001000, 0b000100, 0b000000, 0b000100 ]
    }

    class << self

      # edge case: only one bucket
      def graph_to_file(filename, buckets, left, right)
        puts "buckets #{buckets}"
        width = 256
        height = 64
        png = ChunkyPNG::Image.new(width, height, 0xFF)

        bucket_max = buckets.max.to_f
        write_string(png, 1, 1, 0xFFFFFFFF, "MAX " << bucket_max.to_s)

        write_string(png, 1, height - 6, 0xFFFFFFFF, left)

        x = width - 1 - get_string_width(right)
        write_string(png, x, height - 6, 0xFFFFFFFF, right)

        y = height - 8
        y_max = y - 7.0

        x = 2.0

        x_step = [((width - 4.0) / buckets.size), 1.0].max
        bar_width = [(x_step - 2), 0].max

        buckets.each{|b|
          png.rect(x.to_i, y, x.to_i + bar_width, y - (y_max * (b / bucket_max)).to_i, 0xFFFF00FF, 0xFF0000FF)
          x += x_step
        }

        png.save(filename)
      end

      def get_string_width(str)
        str.chars.reduce(0){|acc,c| acc + (BitFont[c] || BitFont["?"])[0] }
      end

      def draw_character(png, x, y, color, char)
        return BitFont[" "][0] if char == " "
        char = "?" unless BitFont[char]
        rows = BitFont[char]
        y_offset = 0
        rows[1..-1].each do |row|
          x_offset = 0
          while row > 0 do
            png[x + x_offset, y + y_offset] = color if (row & 1) != 0
            x_offset += 1
            row >>= 1
          end
          y_offset += 1
        end
        BitFont[char][0]
      end

      def write_string(png, x, y, color, str)
        x_offset = 0
        str.chars.each do |char|
          x_offset += draw_character(png, x + x_offset, y, color, char)
        end
        x_offset
      end

    end
  end
end
