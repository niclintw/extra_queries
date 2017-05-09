module ExtraQueries
  module CalendarsControllerPatch
    def self.included(base)
      base.class_eval do
        helper :issues_extend
      end
    end
  end
end
