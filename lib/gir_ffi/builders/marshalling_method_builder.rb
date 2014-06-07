require 'gir_ffi/builders/closure_argument_builder'
require 'gir_ffi/builders/callback_return_value_builder'
require 'gir_ffi/builders/mapping_method_builder'

module GirFFI
  module Builders
    # Implements the creation mapping method for a callback or signal
    # handler. This method converts arguments from C to Ruby, and the
    # result from Ruby to C.
    class MarshallingMethodBuilder
      def self.for_signal receiver_info, argument_infos, return_type_info
        vargen = VariableNameGenerator.new

        receiver_builder = ClosureArgumentBuilder.new vargen, receiver_info
        argument_builders = argument_infos.map {|arg|
          ClosureArgumentBuilder.new vargen, arg }
        return_value_info = ReturnValueInfo.new(return_type_info)
        return_value_builder = CallbackReturnValueBuilder.new(vargen, return_value_info)

        foo = Foo.new(return_value_builder,
                      argument_builders,
                      receiver_builder: receiver_builder)

        new foo
      end

      def initialize foo
        @foo = foo
      end

      def method_definition
        code = "def self.marshaller(#{marshaller_arguments.join(', ')})"
        method_lines.each { |line| code << "\n  #{line}" }
        code << "\nend\n"
      end

      def method_lines
        param_values_unpack +
          @foo.parameter_preparation +
          call_to_closure +
          @foo.return_value_conversion +
          return_value
      end

      def return_value
        if (name = @foo.return_value_name)
          ["return_value.set_value #{name}"]
        else
          []
        end
      end

      def call_to_closure
        ["#{capture}wrap(closure.to_ptr).invoke_block(#{@foo.call_argument_names.join(', ')})"]
      end

      def param_values_unpack
        ["#{method_arguments.join(", ")} = param_values.map(&:get_value_plain)" ]
      end

      def capture
        @capture ||= begin
                       names = @foo.capture_variable_names
                       names.any? ? "#{names.join(", ")} = " : ""
                     end
      end

      def method_arguments
        # FIXME: Don't add _ if method_argument_names has more than one element
        @method_arguments ||= @foo.method_argument_names.dup.push('_')
      end

      def marshaller_arguments
        %w(closure return_value param_values _invocation_hint _marshal_data)
      end
    end
  end
end
