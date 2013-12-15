require 'gir_ffi/builders/base_argument_builder'
require 'gir_ffi/builders/closure_to_pointer_convertor'

module GirFFI
  module Builders
    # Implements building pre- and post-processing statements for arguments.
    class ArgumentBuilder < BaseArgumentBuilder
      def inarg
        if has_input_value? && !is_array_length_parameter?
          name
        end
      end

      def retname
        if has_output_value?
          @retname ||= @var_gen.new_var
        end
      end

      def pre
        pr = []
        if has_input_value?
          pr << fixed_array_size_check if needs_size_check?
          pr << array_length_assignment if is_array_length_parameter?
        end
        pr += set_function_call_argument
        pr
      end

      def post
        if has_output_value?
          value = output_value
          ["#{retname} = #{value}"]
        else
          []
        end
      end

      private

      def output_value
        if is_caller_allocated_object?
          callarg
        else
          base = "#{callarg}.to_value"
          if needs_outgoing_parameter_conversion?
            outgoing_conversion base
          else
            base
          end
        end
      end

      def is_array_length_parameter?
        @array_arg
      end

      def needs_size_check?
        specialized_type_tag == :c && type_info.array_fixed_size > -1
      end

      def fixed_array_size_check
        size = type_info.array_fixed_size
        "GirFFI::ArgHelper.check_fixed_array_size #{size}, #{name}, \"#{name}\""
      end

      def skipped?
        @arginfo.skip? ||
          @array_arg && @array_arg.specialized_type_tag == :strv
      end

      def has_output_value?
        (direction == :inout || direction == :out) && !skipped?
      end

      def has_input_value?
        (direction == :inout || direction == :in) && !skipped?
      end

      def array_length_assignment
        arrname = @array_arg.name
        "#{name} = #{arrname}.nil? ? 0 : #{arrname}.length"
      end

      def set_function_call_argument
        result = []
        if skipped?
          value = direction == :in ? "0" : "nil"
          result << "#{callarg} = #{value}"
        end
        if has_output_value?
          result << out_parameter_preparation
        end
        if has_input_value?
          result << ingoing_parameter_conversion
        end
        result
      end

      def out_parameter_preparation
        value = if is_caller_allocated_object?
                  if specialized_type_tag == :array
                    "#{argument_class_name}.new #{type_info.element_type.inspect}"
                  else
                    "#{argument_class_name}.new"
                  end
                else
                  "GirFFI::InOutPointer.for #{type_info.tag_or_class.inspect}"
                end
        "#{callarg} = #{value}"
      end

      def is_caller_allocated_object?
        [ :struct, :array ].include?(specialized_type_tag) &&
          @arginfo.caller_allocates?
      end

      def ingoing_parameter_conversion
        base = if is_closure
                 ClosureToPointerConvertor.new(name).conversion
               elsif @type_info.needs_ruby_to_c_conversion_for_functions?
                 RubyToCConvertor.new(@type_info, name).conversion
               else
                 name
               end

        if has_output_value?
          "#{callarg}.set_value #{base}"
        else
          "#{callarg} = #{base}"
        end
      end
    end
  end
end
