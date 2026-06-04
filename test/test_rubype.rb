require 'minitest_helper'
class TestRubype < Minitest::Test
  def setup
    @string  = 'str'
    @numeric = 1
    @symbol  = :test
    @array   = [1, 2, 3]
    @hash    = { test: :hash }
  end

  def test_correct_type_by_class
    assert_correct_type({ [Numeric] => Numeric }, [@numeric], @numeric)
    assert_correct_type({ [Numeric] => Array   }, [@numeric], @array  )
    assert_correct_type({ [Numeric] => String  }, [@numeric], @string )
    assert_correct_type({ [Numeric] => Hash    }, [@numeric], @hash   )
    assert_correct_type({ [Numeric] => Symbol  }, [@numeric], @symbol )
    assert_correct_type({ [Numeric] => Boolean }, [@numeric], true    )
    assert_correct_type({ [Numeric] => Boolean }, [@numeric], false   )

    assert_correct_type({ [Boolean, Numeric] => Numeric }, [true, @numeric], @numeric)
    assert_correct_type({ [Boolean, Array  ] => Array   }, [true, @array  ], @array)
    assert_correct_type({ [Boolean, String ] => String  }, [true, @string ], @string)
    assert_correct_type({ [Boolean, Hash   ] => Hash    }, [true, @hash   ], @hash)
    assert_correct_type({ [Boolean, Symbol ] => Symbol  }, [true, @symbol ], @symbol)
  end

  def test_correct_type_by_sym
    assert_correct_type({ [Numeric] => :to_i }, [@numeric], @numeric)
    assert_correct_type({ [Numeric] => :to_i }, [@numeric], @string)

    assert_correct_type({ [Numeric] => :to_s }, [@numeric], @numeric)
    assert_correct_type({ [Numeric] => :to_s }, [@numeric], @string)
    assert_correct_type({ [Numeric] => :to_s }, [@numeric], @symbol)
    assert_correct_type({ [Numeric] => :to_s }, [@numeric], @array)
    assert_correct_type({ [Numeric] => :to_s }, [@numeric], @hash)
  end

  def test_wrong_return_type
    assert_wrong_rtn({ [Numeric] => Numeric }, [@numeric], @array)
    assert_wrong_rtn({ [Numeric] => Numeric }, [@numeric], @string)
    assert_wrong_rtn({ [Numeric] => Numeric }, [@numeric], @hash)
    assert_wrong_rtn({ [Numeric] => Numeric }, [@numeric], @symbol)
    assert_wrong_rtn({ [Numeric] => Numeric }, [@numeric], true)

    assert_wrong_rtn({ [Numeric, Numeric] => Numeric }, [@numeric, @numeric], @array)
    assert_wrong_rtn({ [Numeric, Numeric] => Numeric }, [@numeric, @numeric], @string)
    assert_wrong_rtn({ [Numeric, Numeric] => Numeric }, [@numeric, @numeric], @hash)
    assert_wrong_rtn({ [Numeric, Numeric] => Numeric }, [@numeric, @numeric], @symbol)
    assert_wrong_rtn({ [Numeric, Numeric] => Numeric }, [@numeric, @numeric], true)

    assert_wrong_rtn({ [Numeric] => :to_i }, [@numeric], @symbol)
    assert_wrong_rtn({ [Numeric] => :to_i }, [@numeric], @array)
    assert_wrong_rtn({ [Numeric] => :to_i }, [@numeric], @hash)
  end

  def test_wrong_args_type
    assert_wrong_arg({ [Numeric] => Numeric }, [@array ], @numeric)
    assert_wrong_arg({ [Numeric] => Numeric }, [@string], @numeric)
    assert_wrong_arg({ [Numeric] => Numeric }, [@hash  ], @numeric)
    assert_wrong_arg({ [Numeric] => Numeric }, [@symbol], @numeric)
    assert_wrong_arg({ [Numeric] => Numeric }, [true   ], @numeric)

    assert_wrong_arg({ [Numeric, Numeric] => Numeric }, [@numeric, @array ], @numeric)
    assert_wrong_arg({ [Numeric, Numeric] => Numeric }, [@numeric, @string], @numeric)
    assert_wrong_arg({ [Numeric, Numeric] => Numeric }, [@numeric, @hash  ], @numeric)
    assert_wrong_arg({ [Numeric, Numeric] => Numeric }, [@numeric, @symbol], @numeric)
    assert_wrong_arg({ [Numeric, Numeric] => Numeric }, [@numeric, true   ], @numeric)

    assert_wrong_arg({ [Numeric] => :to_i }, [@array ], @numeric)
    assert_wrong_arg({ [Numeric] => :to_i }, [@hash  ], @numeric)
    assert_wrong_arg({ [Numeric] => :to_i }, [@symbol], @numeric)
    assert_wrong_arg({ [Numeric] => :to_i }, [true   ], @numeric)
  end

  def test_any
    assert_correct_type({ [Any] => Any }, [@array ], @numeric)
    assert_correct_type({ [Any] => Any }, [@string], @numeric)
    assert_correct_type({ [Any] => Any }, [@hash  ], @numeric)
    assert_correct_type({ [Any] => Any }, [@symbol], @numeric)

    assert_correct_type({ [Any, Any] => Any }, [@numeric, @array ], @numeric)
    assert_correct_type({ [Any, Any] => Any }, [@numeric, @string], @numeric)
    assert_correct_type({ [Any, Any] => Any }, [@numeric, @hash  ], @numeric)
    assert_correct_type({ [Any, Any] => Any }, [@numeric, @symbol], @numeric)
  end

  def test_type_info
    klass = Class.new.class_eval <<-RUBY_CODE
      def test_mth(n1, n2)
      end
      typesig :test_mth, [Numeric, Numeric] => String
    RUBY_CODE
    Object.const_set('MyClass', klass)

    meth = klass.new.method(:test_mth)
    assert_equal meth.type_info, { [Numeric, Numeric] => String }
    assert_equal meth.arg_types, [Numeric, Numeric]
    assert_equal meth.return_type, String

    assert_raises(Rubype::ReturnTypeError) { meth.(1,2) }
    #assert_equal err.message, %|Expected MyClass#test_mth to return String but got nil instead|

    assert_raises(Rubype::ArgumentTypeError) { meth.(1,'2') }
    #assert_equal err.message, %|Expected MyClass#test_mth's 2nd argument to be Numeric but got "2" instead|
  end

  def test_respects_method_visibility
    klass = Class.new.class_eval <<-RUBY_CODE
      private
      def private_mth(n1, n2)
      end
      typesig :private_mth, [Numeric, Numeric] => NilClass

      protected
      def protected_mth(n1, n2)
      end
      typesig :protected_mth, [Numeric, Numeric] => NilClass
    RUBY_CODE
    instance = klass.new

    # assert_raises(NoMethodError){ instance.private_mth(1,2) }
    assert_raises(NoMethodError){ instance.protected_mth(1,2) }
  end

  def test_keyword_args_are_forwarded
    klass = Class.new do
      def call(id:, prefix: '')
        "#{prefix}#{id}"
      end
      typesig :call, [] => String
    end

    assert_equal 'item-1', klass.new.call(id: 1, prefix: 'item-')
  end

  def test_keyword_args_still_check_return_type
    klass = Class.new do
      def call(id:)
        id
      end
      typesig :call, [] => String
    end

    assert_raises(Rubype::ReturnTypeError) { klass.new.call(id: 1) }
  end

  def test_keyword_syntax_for_positional_hash_is_checked
    klass = Class.new do
      def call(options)
        options
      end
      typesig :call, [Hash] => Hash
    end

    assert_equal({ value: 1 }, klass.new.call(value: 1))
  end

  def test_keyword_syntax_for_positional_hash_can_fail_type_check
    klass = Class.new do
      def call(options)
        options
      end
      typesig :call, [Array] => Hash
    end

    assert_raises(Rubype::ArgumentTypeError) { klass.new.call(value: 1) }
  end

  def test_block_is_forwarded
    klass = Class.new do
      def call(value)
        yield value
      end
      typesig :call, [Numeric] => Numeric
    end

    assert_equal 4, klass.new.call(2) { |value| value * 2 }
  end

  def test_type_info_is_scoped_by_owner
    numeric_klass = Class.new do
      def call
        1
      end
      typesig :call, [] => Numeric
    end

    string_klass = Class.new do
      def call
        'str'
      end
      typesig :call, [] => String
    end

    assert_equal({ [] => Numeric }, numeric_klass.new.method(:call).type_info)
    assert_equal({ [] => String }, string_klass.new.method(:call).type_info)
  end

  def test_invalid_typesig
    assert_raises(Rubype::InvalidTypesigError) do
       Class.new.class_eval <<-RUBY_CODE
        def mth(n1, n2)
        end
        typesig :mth, Numeric => NilClass
      RUBY_CODE
    end
  end

  def test_empty_typesig_is_invalid
    assert_raises(Rubype::InvalidTypesigError) do
       Class.new.class_eval <<-RUBY_CODE
        def mth
        end
        typesig :mth, {}
      RUBY_CODE
    end
  end

  def test_for_readme
    assert_raises(Rubype::ArgumentTypeError) do
       eval <<-RUBY_CODE
        class MyClass
          def sum(x, y)
            x.to_i + y
          end
          typesig :sum, [Numeric, Numeric] => Numeric
        end

        MyClass.new.sum(:has_no_to_i, 2)
      RUBY_CODE
    end
  end

  private
    def assert_equal_to_s(str, val)
      assert_equal str, val.to_s
    end

    def assert_correct_type(type_list, args, val)
      assert_equal val, define_test_method(type_list, args, val).call(*args)
    end

    def assert_wrong_arg(type_list, args, val)
      assert_raises(Rubype::ArgumentTypeError) { define_test_method(type_list, args, val).call(*args) }
    end

    def assert_wrong_rtn(type_list, args, val)
      assert_raises(Rubype::ReturnTypeError) { define_test_method(type_list, args, val).call(*args) }
    end

    def define_test_method(type_list, args, val)
      klass = Class.new.class_eval <<-RUBY_CODE
        def call(#{arg_literal(args.count)})
          #{obj_literal(val)}
        end
        typesig :call, #{obj_literal(type_list)}
      RUBY_CODE

      klass.new
    end

    def obj_literal(obj)
      "ObjectSpace._id2ref(#{obj.__id__})"
    end

    def arg_literal(count)
      ('a'..'z').to_a[0..count-1].join(',')
    end
end
