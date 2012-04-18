require 'acts_as_tree/active_record/acts/tree'
require 'acts_as_tree/version'

module ActsAsTree
  if defined? Rails::Railtie
    require 'rails'
    class Railtie < Rails::Railtie
      initializer 'acts_as_tree.insert_into_active_record' do
        ActiveSupport.on_load :active_record do
          ActsAsTree::Railtie.insert
        end
      end
    end
  end

  class Railtie
    def self.insert
      if defined?(ActiveRecord)
        ActiveRecord::Base.send(:include, ActiveRecord::Acts::Tree)
      end
    end
  end
end