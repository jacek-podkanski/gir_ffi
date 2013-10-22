require 'gir_ffi/builders/return_value_builder'

module GirFFI
  module Builders
    # Implements the creation mapping method for a callback or signal
    # handler. This method converts arguments from C to Ruby, and the
    # result from Ruby to C.
    class MappingMethodBuilder
      # TODO: Make CallbackArgumentBuilder accept argument name
      # TODO: Fix name of #post method
      class CallbackArgumentBuilder < ReturnValueBuilder
        def post
          if specialized_type_tag == :enum
            ["#{retname} = #{argument_class_name}[#{callarg}]"]
          else
            super
          end
        end

        def retval
          if specialized_type_tag == :enum
            retname
          else
            super
          end
        end
      end

      def initialize argument_infos, return_type_info
        @argument_infos = argument_infos
        @return_type_info = return_type_info
      end

      attr_reader :argument_infos
      attr_reader :return_type_info

      def method_definition
        code = "def self.call_with_argument_mapping(#{method_arguments.join(', ')})"
        method_lines.each { |line| code << "\n  #{line}" }
        code << "\nend\n"
      end

      def method_lines
        parameter_preparation + call_to_proc + return_value_conversion + return_value
      end

      def return_value
        if return_value_builder.is_relevant?
          ["return #{return_value_builder.retval}"]
        else
          []
        end
      end

      def return_value_conversion
        return_value_builder.post
      end

      def call_to_proc
        ["#{capture}_proc.call(#{call_arguments.join(', ')})"]
      end

      def parameter_preparation
        argument_builders.map(&:post).flatten
      end

      def capture
        @capture ||= return_value_builder.is_relevant? ?
          "#{return_value_builder.callarg} = " :
          ""
      end

      def call_arguments
        @call_arguments ||= argument_builders.map(&:retval)
      end

      def method_arguments
        @method_arguments ||= argument_builders.map(&:callarg).unshift('_proc')
      end

      def return_value_builder
        @return_value_builder ||= ReturnValueBuilder.new(vargen, return_type_info)
      end

      def argument_builders
        unless defined?(@argument_builders)
          @argument_builders = argument_infos.map {|arg|
            CallbackArgumentBuilder.new vargen, arg.argument_type }
          set_up_argument_relations(@argument_builders)
        end
        @argument_builders
      end

      def set_up_argument_relations(builders)
        argument_infos.each do |arg|
          if (idx = arg.closure) >= 0
            builders[idx].is_closure = true
          end
        end
      end

      def vargen
        @vargen ||= GirFFI::VariableNameGenerator.new
      end
    end
  end
end

