# frozen_string_literal: true

require 'ffi'
require 'ffi/bit_masks'

require 'ffi-gobject_introspection'

require 'gir_ffi-base'

require 'gir_ffi/ffi_ext'
require 'gir_ffi/class_base'
require 'gir_ffi/type_map'
require 'gir_ffi/info_ext'
require 'gir_ffi/in_pointer'
require 'gir_ffi/in_out_pointer'
require 'gir_ffi/sized_array'
require 'gir_ffi/zero_terminated'
require 'gir_ffi/arg_helper'
require 'gir_ffi/builder'
require 'gir_ffi/user_defined_object_info'
require 'gir_ffi/builders/user_defined_builder'
require 'gir_ffi/version'

module GirFFI
  # Core GirFFI interface.
  module Core
    def setup(namespace, version = nil)
      namespace = namespace.to_s
      Builder.build_module namespace, version
    end

    def define_type(klass, &block)
      info = UserDefinedObjectInfo.new(klass, &block)
      Builders::UserDefinedBuilder.new(info).build_class

      klass.gtype
    end
  end
end

GirFFI.extend GirFFI::Core
