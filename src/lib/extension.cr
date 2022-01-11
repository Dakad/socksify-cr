# Mainly to monkey-patch Array and String in order to inject pack and unpack methods
#
# REF: https://github.com/crystal-lang/crystal/wiki/FAQ#user-content-is-there-an-equivalent-to-rubys-arraypackstringunpack
# REF: https://therubyist.org/2020/05/07/rewriting-rubys-pack-and-unpack-methods-in-crystal/
# REF: https://gist.github.com/fukaoi/d030127d0abd67e572ba6a157a29bd12
# REF:
#
# What Are Pack and Unpack?
# -------------------------
# The Ruby `Array#pack()` method takes an Array of data (usually numbers) and “packs” the data together into a String.
# This could be used to take binary data and turn it back into something you can read.
# The opposite of this is `String#unpack()`, which allows you to take apart (or “unpack”) a String into a set of numbers. In reality, this packing refers to arranging data into a specific format and is pretty low-level stuff
# Both methods can take a directive with a special and specific meaning.
# Special chars:
#   * : All remaining element will converted using the prior directive
#   _ or ! : Some directive are followed by this char, meaning to use the underlying platform's native size for the specified type; otherwise, they use a platform-independent size
# Directives:
#   C       | Integer | 8-bit unsigned (unsigned char)
#   S       | Integer | 16-bit unsigned, native endian (uint16_t)
#   S_, S!  | Integer | unsigned short, native endian
#   E       | Float   | double-precision, little-endian byte order
#   e       | Float   | single-precision, little-endian byte order
#    a      | String  | arbitrary binary string (null padded, count is width)
#    U      | Integer | UTF-8 character
#    w      | Integer | BER-compressed integer
#    n      | Integer | 16-bit unsigned, network (big-endian) byte order
#    N      | Integer | 32-bit unsigned, network (big-endian) byte order
#    H      | String  | hex string (high nibble first)
#    h      | String  | hex string (low nibble first)
#    x      | ---     | skip forward one byte / null byte


class Array

  # Ruby equivalent to
  # [65, 66, 67].pack "C*"  #=> "ABC"
  def self.pack_to_C(arr : Array(Int)) : String
    String.build do |io|
      arr.each do |number|
        io.write_byte number.to_u8
      end
    end
  end

  # Ruby equivalent to
  # [97, -62, -78, 98].pack "c*" #=> "a²b"
  # [65, 66, 67].pack "c*"  #=> "ABC"
  def self.pack_to_c(arr : Array(Int)) : String
    String.build do |io|
      arr.each do |number|
        io.write_byte (number < 0 ? number + 256 : number).to_u8
      end
    end
  end

  # Packing using unsigned, 4-byte (32-bit) "words"
  # Ruby equivalent to
  # [2003792484].pack "N*" #=> "word"
  # [1752524645, 543320436, 544171552, 2003792484].pack "N*" #=> "huge bit of word"
  def self.pack_to_N(arr : Array(Int32)) : String
    String.build do |io|
      arr.each do |number|
        # Use Big-Endian because of how the 32-bit words are joined
        io.write_bytes number.to_u32, IO::ByteFormat::BigEndian
      end
    end
  end

  # Packing using unsigned, 2-byte (16-bit) "words"
  # Ruby equivalent to
  # [30575, 29284].unpack "n*" #=> "word"
  def self.pack_to_n(arr : Array(Int16|Int32)) : String
    String.build do |io|
      arr.each do |number|
        # Use Big-Endian because of how the 16-bit words are joined
        io.write_bytes number.to_u16, IO::ByteFormat::BigEndian
      end
    end
  end


  def pack(format : String) : String
    raise NotImplementedError.new "Array.pack"
    # case format[0]
    # when "c"  then pack_to_c
    # when "C"  then pack_to_C
    # when "n"  then pack_to_n
    # when "N"  then pack_to_N
    # else
    #   raise RuntimeError.new "Unsupported directive format '#{format}'"
    # end
  end
end
