module ProtocolBuffers

  class EncodeError < StandardError; end

  module Encoder # :nodoc: all
    def self.encode(io, message)
      unless message.valid?
        raise(EncodeError, "invalid message")
      end

      message.fields.each do |tag, field|
        next unless message.value_for_tag?(tag)

        value = message.value_for_tag(tag)
        wire_type = field.wire_type
        tag = (field.tag << 3) | wire_type

        if field.repeated?
          value.each { |i| serialize_field(io, tag, wire_type,
                                           field.serialize(i)) }
        else
          serialize_field(io, tag, wire_type, field.serialize(value))
        end
      end

      message.each_unknown_field do |tag_int, value|
        wire_type = tag_int & 0b111
        serialize_field(io, tag_int, wire_type, value)
      end
    end

    def self.serialize_field(io, tag, wire_type, serialized)
      # write the tag
      Varint.encode(io, tag)

      # see comment in decoder.rb about magic numbers
      case wire_type
      when 0 # VARINT
        Varint.encode(io, serialized)
      when 1, 5 # FIXED64, FIXED32
        io.write(serialized)
      when 2 # LENGTH_DELIMITED
        Varint.encode(io, serialized.length)
        io.write(serialized)
      when 3, 4 # deprecated START_GROUP/END_GROUP types
        raise(EncodeError, "groups are deprecated and unsupported")
      else
        raise(EncodeError, "unknown wire type: #{wire_type}")
      end
    end
  end

end
