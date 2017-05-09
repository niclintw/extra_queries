module ExtraQueries
  module IssuePatch
    def self.included(base)
      base.send :include, InstanceMethods
    end

    module InstanceMethods
      def eq_author_branch
        self.author.user_department.try(:name)
      end
    end
  end
end