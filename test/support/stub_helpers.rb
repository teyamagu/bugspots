# frozen_string_literal: true

module StubHelpers
  private

  def with_stubbed_singleton_method(klass, method_name, return_value)
    singleton = klass.singleton_class
    original_method = klass.method(method_name)

    singleton.send(:define_method, method_name) { |*_args, **_kwargs, &_block| return_value }
    yield
  ensure
    singleton.send(:define_method, method_name) do |*args, **kwargs, &block|
      original_method.call(*args, **kwargs, &block)
    end
  end
end
