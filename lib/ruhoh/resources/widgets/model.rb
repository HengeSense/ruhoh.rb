module Ruhoh::Resources::Widgets
  class Model < Ruhoh::Base::Page::Model
    def generate
      data = parse_page_file['data']
      data['pointer'] = @pointer
      data['id'] = @pointer['id']

      {
        "#{@pointer['id']}" => data
      }
    end
  end
end