require_relative 'rubype/version'
require_relative 'rubype/contract'

module Rubype
  module TypeInfo; end
  Module.send(:include, TypeInfo)
  Symbol.send(:include, TypeInfo)
  @@typed_methods = Hash.new { |hash, owner| hash[owner] = {} }

  class << self
    def define_typed_method(owner, meth, type_info_hash, __proxy__)
      raise InvalidTypesigError unless valid_type_info_hash?(type_info_hash)
      arg_types, rtn_type = *type_info_hash.first

      contract = Contract.new(arg_types, rtn_type, owner, meth)
      @@typed_methods[owner][meth] = contract
      @@typed_methods[__proxy__][meth] = contract

      add_typed_method_to_proxy(owner, meth, __proxy__) do |*args, **kwargs, &block|
        checked_args =
          if kwargs.empty? || args.length >= arg_types.length
            args
          else
            args + [kwargs]
          end

        contract.assert_args_type(checked_args)
        contract.assert_rtn_type(super(*args, **kwargs, &block))
      end
    end

    def typed_methods
      @@typed_methods
    end

    private
      def valid_type_info_hash?(type_info_hash)
        return false unless type_info_hash.is_a?(Hash)
        first = type_info_hash.first
        first && first[0].is_a?(Array)
      end
  end
end

require_relative 'rubype/core_ext'
