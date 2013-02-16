module Ruhoh::Base
  class Compiler
    attr_reader :collection

    def initialize(collection)
      @ruhoh = collection.ruhoh
      @collection = collection
    end

    def resource_name
      @collection.registered_name
    end
  end
end
