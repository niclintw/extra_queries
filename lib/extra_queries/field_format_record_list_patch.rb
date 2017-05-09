module ExtraQueries
  module FieldFormatRecordListPatch
    def self.included(base)
      base.send :include, InstanceMethods

      base.class_eval do
        alias_method_chain :query_filter_values, :equ
      end
    end

    module InstanceMethods
      def query_filter_values_with_equ(custom_field, query)
        if Setting.plugin_extra_queries['custom_query_page_enabled'] && custom_field.format.respond_to?(:ajax_supported) && custom_field.format.ajax_supported && custom_field.ajaxable
          if query.eq_ajax_like.blank?
            params = query.eq_controller_params || {}
            fields = params[:fields] || params[:f]
            values = params[:values] || params[:v]
            field = "cf_#{custom_field.id}"
            vals = []

            if fields.is_a?(Array) && (values.nil? || values.is_a?(Hash)) && fields.include?(field) && values && values[field]
              vals = Array.wrap(values[field] || []).map(&:to_s)
            end

            return [] if vals.blank?

            if self.respond_to?(:possible_values_records)
              res = []
              possible_values_records(custom_field, query.project, nil, vals) { |it, id, value| res << [value, id] }
              res
            else
              (query_filter_values_without_equ(custom_field, query) || []).select { |it| vals.include?(it[1].to_s) }
            end
          else
            if self.respond_to?(:possible_values_records)
              res = []
              possible_values_records(custom_field, query.project, query.eq_ajax_like, nil) { |it, id, value| res << [value, id] }
              res
            else
              (query_filter_values_without_equ(custom_field, query) || []).select { |it| it[1].to_s.mb_chars.downcase.include?(query.eq_ajax_like.to_s.mb_chars.downcase) }
            end
          end
        else
          query_filter_values_without_equ(custom_field, query)
        end
      end
    end
  end
end