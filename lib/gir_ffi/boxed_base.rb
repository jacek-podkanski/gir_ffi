# frozen_string_literal: true
require 'gir_ffi/class_base'

module GirFFI
  # Base class for generated classes representing boxed types.
  class BoxedBase < StructBase
    def initialize
      store_pointer(self.class::Struct.new.to_ptr)
    end

    def self.make_finalizer(struct, gtype)
      proc do
        if struct.owned?
          struct.owned = false
          GObject.boxed_free gtype, struct.to_ptr
        end
      end
    end

    # Wrap value and take ownership of it
    def self.wrap_own(val)
      wrap(val).tap { |it| it && it.struct.owned = true }
    end

    # Wrap an owned copy of the struct represented by val
    def self.wrap_copy(val)
      # TODO: Is this needed? We may get away with just copying on transfer away from us.
      copy(wrap(val)).tap { |it| it && it.struct.owned = true }
    end

    def self.copy(val)
      return unless val
      ptr = GObject.boxed_copy(gtype, val)
      wrap(ptr)
    end

    private

    def store_pointer(ptr)
      super
      make_finalizer
    end

    def make_finalizer
      gtype = self.class.gtype
      ObjectSpace.define_finalizer self, self.class.make_finalizer(@struct, gtype)
    end
  end
end
