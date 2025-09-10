module Charai
  class InjectedScript
    def initialize(realm, handle)
      @realm = realm
      @handle = handle
    end

    def e(value)
      @realm.script_evaluate(value, as_handle: false)
    end

    def h(value)
      @realm.script_evaluate(value, as_handle: true)
    end

    def getprop(name, as_handle: false)
      c(
        function_declaration: "(injected) => injected.#{name}",
        as_handle: as_handle,
      )
    end

    def call(name, *args, as_handle: false)
      c(
        function_declaration: "(injected, ...args) => injected.#{name}(...args)",
        args: args,
        as_handle: as_handle,
      )
    end

    private

    def c(function_declaration:, args: [], as_handle: false)
      @realm.script_call_function(
        function_declaration,
        arguments: [@handle, *args],
        as_handle: as_handle)
    end
  end
end
