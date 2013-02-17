require 'ruhoh/programs/watch'
class Ruhoh
  module Program
    # Public: A program for running ruhoh as a rack application
    # which renders singular pages via their URL.
    # 
    # Examples
    #
    #  In config.ru:
    #
    #   require 'ruhoh'
    #   run Ruhoh::Program.preview
    #
    # Returns: A new Rack builder object which should work inside config.ru
    def self.preview(opts={})
      opts[:watch] ||= true
      opts[:env] ||= 'development'
      
      ruhoh = Ruhoh.new
      ruhoh.setup
      ruhoh.env = opts[:env]
      ruhoh.setup_paths
      ruhoh.setup_plugins unless opts[:enable_plugins] == false

      # initialize the routes dictionary for all page resources.
      ruhoh.db.routes_initialize
      
      Ruhoh::Program.watch(ruhoh) if opts[:watch]
      Rack::Builder.new {
        use Rack::Lint
        use Rack::ShowExceptions

        # ruhoh.db.urls contains url endpoints as registered by the resources.
        # The urls are mapped to the resource's individual rack-compatable Previewer class.
        # Note page-like resources (posts, pages) don't render uniform url endpoints,
        # since presumably they define customized permalinks per singular resource.
        # Page-like resources are handled the root mapping below.
        sorted_urls = ruhoh.db.urls.each.map {|k, v| {"name" => k, "url" => v} }
        sorted_urls = sorted_urls.sort { |a, b| b["url"].length <=> a["url"].length }
        sorted_urls.each do |h|
          next if h["name"] == "base_path"
          next unless ruhoh.resources.exists?(h["name"])
          map h["url"] do
            if ruhoh.resources.previewer?(h["name"])
              run ruhoh.resources.load_previewer(h["name"])
            else
              collection = ruhoh.resources.load_collection(h["name"])
              try_files = collection.paths.reverse.map do |data|
                Rack::File.new(File.join(data["path"], collection.namespace))
              end

              run Rack::Cascade.new(try_files)
            end
          end
        end

        # The generic Page::Previewer is used to render any/all page-like resources,
        # since they likely have arbitrary urls based on permalink settings.
        map '/' do
          run Ruhoh::Base::Pages::Previewer.new(ruhoh)
        end
      }
    end
  end
end