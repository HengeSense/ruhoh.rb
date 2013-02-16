require 'ruhoh/resources_interface'

class Ruhoh
  # Public: Database class for interacting with "data" in Ruhoh.
  class DB
    attr_reader :routes

    def initialize(ruhoh)
      @ruhoh = ruhoh
      @content = {}
      @config = {}
      @urls = {}
      @paths = {}
      @routes = {}
    end

    def route_add(route, pointer)
      @routes[route] = pointer
    end

    def route_delete(route)
      @routes.delete(route)
    end

    def routes_initialize
      @ruhoh.resources.acting_as_pages.each {|r| __send__(r) }
      @routes
    end

    # Get a data endpoint from pointer
    # Note this differs from update in that
    # it should retrieve the cached version.
    def get(pointer)
      name = pointer['resource'].downcase
      id = pointer['id']
      raise "Invalid data type #{name}" unless self.respond_to?(name)
      data = self.__send__(name)[id]
      data ? data : self.update(pointer)
    end
    
    # Update a data endpoint
    #
    # name_or_pointer - String, Symbol or pointer(Hash)
    #
    # If pointer is passed, will update the singular resource only.
    # Useful for updating only the resource that have changed.
    #
    # Returns the data that was updated.
    def update(name_or_pointer)
      if name_or_pointer.is_a?(Hash)
        id = name_or_pointer['id']
        if id
          name = name_or_pointer['resource'].downcase
          if(@ruhoh.env == "production" && instance_variable_defined?("@_#{name}"))
            instance_variable_get("@_#{name}")[id]
          else
            resource = @ruhoh.resources.load_collection(name)
            data = resource.generate(id).values.first
            endpoint = self.instance_variable_get("@_#{name}") || {}
            endpoint[id] = data
            data
          end
        end
      else
        name = name_or_pointer.downcase # name is a stringified constant.
        if(@ruhoh.env == "production" && instance_variable_defined?("@_#{name}"))
          instance_variable_get("@_#{name}")
        else
          data = @ruhoh.resources.load_collection(name).generate
          instance_variable_set("@_#{name}", data)
          data
        end
      end
    end

    # return a given resource's file content
    # TODO: Cache this in compile mode but not development mode.
    def content(pointer)
      name = pointer['resource'].downcase # name is a stringified constant.
      model = @ruhoh.resources.model(name).new(@ruhoh, pointer)
      
      # TODO:
      # possible collisions here: ids are only unique relative to their resource dictionary.
      # that's the whole point of the pointer... =/
      @content[pointer['id']] = model.content
    end
    
    def urls
      @urls["base_path"] = @ruhoh.base_path
      return @urls if @urls.keys.length > 1 # consider base_url

      @ruhoh.resources.all.each do |name|
        next unless @ruhoh.resources.collection?(name)
        collection = @ruhoh.resources.load_collection(name)
        next unless collection.respond_to?(:url_endpoint)
        @urls[name] = @ruhoh.to_url(collection.url_endpoint)
      end
      
      @urls
    end
  
    # Get the config for a given resource.
    def config(name)
      name = name.downcase
      return @config[name] if @config[name]
      @config[name] = @ruhoh.resources.load_collection(name).config
    end
    
    def clear(name)
      self.instance_variable_set("@_#{name}", nil)
    end

    def method_missing(name, *args, &block)
      return data_for(name.to_s) if @ruhoh.resources.exist?(name.to_s)
      super
    end

    def respond_to?(method)
      return true if @ruhoh.resources.exist?(method.to_s)
      super
    end

    protected

    # Lazy-load all data endpoints but cache the result for this cycle.
    def data_for(resource)
      if instance_variable_defined?("@_#{resource}")
        instance_variable_get("@_#{resource}")
      else
        update(resource)
      end
    end
  end #DB
end #Ruhoh