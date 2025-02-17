# frozen_string_literal: true

require 'gir_ffi/builders/object_builder'
require 'gir_ffi/g_type'

module GirFFI
  module Builders
    # Implements the creation of GObject subclasses from Ruby.
    class UserDefinedBuilder < ObjectBuilder
      def initialize(info)
        @info = info
      end

      def setup_class
        setup_layout
        register_type
        setup_constants
        setup_property_accessors
        setup_initializer
        TypeBuilder::CACHE[@gtype] = klass
      end

      def target_gtype
        @gtype ||= klass.gtype
      end

      private

      def register_type
        @gtype = GObject.type_register_static(parent_gtype.to_i,
                                              info.g_name,
                                              gobject_type_info, 0)
        included_interfaces.each do |interface|
          ifinfo = gobject_interface_info interface
          GObject.type_add_interface_static @gtype, interface.gtype, ifinfo
        end
      end

      def parent_info
        @info.parent
      end

      def parent_gtype
        @info.parent_gtype
      end

      def interface_gtypes
        included_interfaces.map { |interface| GType.new(interface.gtype) }
      end

      def included_interfaces
        klass.included_interfaces
      end

      def klass
        @klass ||= @info.described_class
      end

      def gobject_type_info
        GObject::TypeInfo.new.tap do |type_info|
          type_info.class_size = class_size
          type_info.instance_size = instance_size
          type_info.class_init = class_init_proc
        end
      end

      def gobject_interface_info(interface)
        GObject::InterfaceInfo.new.tap do |interface_info|
          interface_info.interface_init = interface_init_proc(interface)
        end
      end

      def class_init_proc
        proc do |type_class_or_ptr, _data|
          object_class_ptr = type_class_or_ptr.to_ptr
          setup_properties object_class_ptr
          setup_vfuncs object_class_ptr
        end
      end

      def interface_init_proc(interface)
        proc do |interface_or_ptr, _data|
          interface_ptr = interface_or_ptr.to_ptr
          setup_interface_vfuncs interface, interface_ptr
        end
      end

      def instance_size
        if property_fields.any?
          last_property = property_fields.last
          size = last_property.offset
          type_size = FFI.type_size(last_property.ffi_type)
          size += [type_size, field_alignment].max
        else
          size = parent_gtype.instance_size
        end
        size
      end

      def class_size
        parent_gtype.class_size + interface_gtypes.map(&:class_size).inject(0, :+)
      end

      def setup_properties(object_class_ptr)
        object_class = GObject::ObjectClass.wrap object_class_ptr

        object_class.get_property = property_getter
        object_class.set_property = property_setter

        property_fields.each_with_index do |property, index|
          object_class.install_property index + 1, property.param_spec
        end
      end

      def property_getter
        proc do |object, _property_id, value, pspec|
          value.set_value object.send(pspec.accessor_name)
        end
      end

      def property_setter
        proc do |object, _property_id, value, pspec|
          object.send("#{pspec.accessor_name}=", value.get_value)
        end
      end

      def setup_vfuncs(object_class_ptr)
        super_class_struct =
          superclass.gir_ffi_builder.object_class_struct::Struct.new(object_class_ptr)

        info.vfunc_implementations.each do |impl|
          setup_vfunc parent_info, super_class_struct, impl
        end
      end

      def setup_interface_vfuncs(interface, interface_ptr)
        interface_builder = interface.gir_ffi_builder

        interface_struct = interface_builder.interface_struct::Struct.new(interface_ptr)
        interface_info = interface_builder.info

        info.vfunc_implementations.each do |impl|
          setup_vfunc interface_info, interface_struct, impl
        end
      end

      def setup_vfunc(ancestor_info, ancestor_struct, impl)
        vfunc_name = impl.name
        vfunc_info = ancestor_info.find_vfunc vfunc_name.to_s
        return unless vfunc_info

        install_vfunc ancestor_struct, vfunc_name, vfunc_info, impl.implementation
      end

      def install_vfunc(container_struct, vfunc_name, vfunc_info, implementation)
        vfunc = VFuncBuilder.new(vfunc_info).build_class
        container_struct[vfunc_name] = vfunc.from implementation
      end

      def properties
        @properties ||= info.properties
      end

      def layout_specification
        parent_spec = [:parent, superclass::Struct]

        fields_spec = property_fields.flat_map do |property_info|
          [property_info.field_symbol, property_info.ffi_type, property_info.offset]
        end

        parent_spec + fields_spec
      end

      def field_alignment
        @field_alignment ||= superclass::Struct.alignment
      end

      def setup_property_accessors
        property_fields.each do |field_info|
          FieldBuilder.new(field_info, klass).build
        end
      end

      def property_fields
        @property_fields ||=
          begin
            offset = parent_gtype.instance_size
            properties.map do |param_spec|
              field_info = UserDefinedPropertyInfo.new(param_spec, info, offset)
              type_size = FFI.type_size(field_info.ffi_type)
              offset += [type_size, field_alignment].max
              field_info
            end
          end
      end

      def method_introspection_data(_method)
        nil
      end
    end
  end
end
