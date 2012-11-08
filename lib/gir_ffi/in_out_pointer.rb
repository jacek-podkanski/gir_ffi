module GirFFI
  # The InOutPointer class handles conversion between ruby types and
  # pointers for arguments with direction :inout and :out.
  class InOutPointer < FFI::Pointer
    attr_reader :value_type, :sub_type

    def initialize ptr, type, ffi_type, sub_type=nil
      super ptr
      @ffi_type = ffi_type
      @value_type = type
      @sub_type = sub_type
    end

    private :initialize

    def to_value
      value = self.send "get_#{@ffi_type}", 0
      adjust_value_out value
    end

    def to_sized_array_value size
      # FIXME: Simulated Polymorphism.
      raise "Not allowed" if @value_type != :pointer or @sub_type.nil?
      block = self.read_pointer
      return nil if block.null?
      ArgHelper.ptr_to_typed_array @sub_type, block, size
    end

    def self.for type, sub_type=nil
      ffi_type = TypeMap.map_basic_type_or_string type
      ptr = AllocationHelper.safe_malloc(FFI.type_size ffi_type)
      ptr.send "put_#{ffi_type}", 0, nil_value_for_ffi_type(ffi_type)
      self.new ptr, type, ffi_type, sub_type
    end

    def self.from type, value, sub_type=nil
      if Array === type
        _, sub_t = *type
        # TODO: Take array type into account (zero-terminated or not)
        return self.from_array sub_t, value
      end
      value = adjust_value_in type, value
      ffi_type = TypeMap.map_basic_type_or_string type
      ptr = AllocationHelper.safe_malloc(FFI.type_size ffi_type)
      ptr.send "put_#{ffi_type}", 0, value
      self.new ptr, type, ffi_type, sub_type
    end

    def self.from_array type, array
      return nil if array.nil?
      ptr = InPointer.from_array(type, array)
      self.from :pointer, ptr, type
    end

    def self.for_array type
      self.for :pointer, type
    end

    class << self
      def adjust_value_in type, value
        case type
        when :gboolean
          (value ? 1 : 0)
        when :utf8
          InPointer.from :utf8, value
        else
          value
        end
      end

      def nil_value_for_ffi_type ffi_type
        ffi_type == :pointer ? nil : 0
      end
    end

    private

    def adjust_value_out value
      case @value_type
      when :gboolean
        (value != 0)
      when :utf8
        ArgHelper.ptr_to_utf8 value
      else
        value
      end
    end

  end
end

