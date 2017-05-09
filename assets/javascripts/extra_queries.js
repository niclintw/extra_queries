!function($) {
  "use strict"; // jshint ;_;

  var eq_button = function(element, options) {
    this.$element = $(element);
    this.options = $.extend({}, $.fn.eq_button.defaults, options);

    this.filtered = false;
    this.options.ajaxable = this.options.ajaxable || this.$element.hasClass(this.options.ajaxable_class);

    if (this.options.just_search) {
      this.$values_container = this.$element.find('.' + this.options.values_container.class);
      this.$clear_values_link = this.$values_container.find('.' + this.options.values_container.clear_class);
      this.$search_field = this.$values_container.find('.' + this.options.search_field_class);
    } else {
      this.$modal = $('#modal-' + this.$element.attr('id'));
      this.$operator = this.$modal.find('.' + this.options.operator_container_class + ' .' + this.options.operator_class);
      this.$values_container = this.$modal.find('.' + this.options.values_container.class);
      this.$clear_values_link = this.$values_container.find('.' + this.options.values_container.clear_class);
      this.$search_field = this.$values_container.find('.' + this.options.search_field_class);

      this.field = this.$element.attr('data-field');
      this.title = this.$element.attr('title');
      if (this.options.ajaxable) {
        this.ajax_url = this.$element.attr('data-url');
        this.ajax = undefined;
        this.ajax_loading = false;
      }
      this.visible = false;
      this.old_search = '';

      this.build_button();
    }
    this.listen();
  };

  eq_button.prototype = {
    constructor: eq_button,
    build_button: function() {
      this.$element.html('');
      this.reset_button();
      var html = '<b class="' + this.options.caret_class + '"></b>';
      if (this.options.can_delete) {
        html += '<span class="' + this.options.delete_class + '" title="' + this.options.msg.delete_filter + '">×</span>';
      }
      this.$element.append(html);

      if (this.$modal.find('.' + this.options.modal_buttons.class).length == 0) {
        html = '<div class="' + this.options.modal_buttons.class + '">';
        html += '<a href="#" class="' + this.options.button_class + ' ' + this.options.button_small_class + ' ' + this.options.button_success_class + ' ' + this.options.modal_buttons.buttons_save_class + '">' + this.options.msg.button_save + '</a>';
        html += '<a href="#" class="' + this.options.button_class + ' ' + this.options.button_small_class + ' ' + this.options.modal_buttons.buttons_cancel_class + '">' + this.options.msg.button_cancel + '</a>';
        html += '</div>';
        this.$modal.append(html);
      }

      this.$element.addClass(this.options.button_class).addClass('link_to_modal block-preferred click_out');
      this.save_button();
    },
    listen: function() {
      if (!this.options.just_search) {
        this.$element.on('click', $.proxy(this.open, this));
        this.$element.on('click', '.' + this.options.delete_class, $.proxy(this.remove, this));
        this.$modal.on('click', '.' + this.options.modal_buttons.buttons_cancel_class, $.proxy(this.close, this));
        this.$modal.on('click', '.' + this.options.modal_buttons.buttons_save_class, $.proxy(this.save_and_close_handler, this));
        this.$modal.on('modal_window_hidden',       $.proxy(this.modal_hidden_handler, this));
        this.$modal.on('modal_window_shown',        $.proxy(this.modal_shown_handler, this));
        this.$operator.on('change',                 $.proxy(this.set_values_group_visibility, this));
        this.$modal.on('keyup',                     $.proxy(this.key_press_handler, this));
      }
      this.$clear_values_link.on('click',         $.proxy(this.clear_values_handler, this));
      this.$search_field.on('keyup change click', $.proxy(this.search_handler, this));
      this.$values_container.on('click', 'li.' + this.options.values_container.item_class + ' label a', $.proxy(this.item_link_click_handler, this));
    },

    key_press_handler: function(e) {
      if (!this.visible) { return; }
      if (e.keyCode == 13) {
        this.$modal.find('.' + this.options.modal_buttons.buttons_save_class).trigger('click');
      } else if (e.keyCode == 27) {
        this.$modal.find('.' + this.options.modal_buttons.buttons_cancel_class).trigger('click');
      }
    },
    item_link_click_handler: function(e) {
      var $ch = $(e.target).parents('li.' + this.options.values_container.item_class).find('input[type="checkbox"], input[type="radio"]');
      if ($ch.length == 0) { return; }

      $ch.prop('checked', !$ch[0].checked);

      return false;
    },

    search_handler: function() {
      this.search(this.$search_field.val());
    },
    clear_values_handler: function() {
      this.clear_values();
      if (this.options.ajaxable) {
        this.current_values_group().not(':checked').closest('li').remove();
      }
      return false;
    },
    modal_shown_handler: function() {
      this.$modal.find('input:visible, select:visible').not('.' + this.options.operator_class).first().focus();
    },
    modal_hidden_handler: function() {
      this.visible = false;
      this.$element.removeClass('open');
      this.reset_button();
      this.$element.trigger('closed');
    },
    save_and_close_handler: function() {
      this.save_button();
      this.close();
      return false;
    },

    build_title: function() {
      this.$element.find('.' + this.options.wrap_title.class).remove();

      var html = '<span class="' + this.options.wrap_title.class + '">';
      html += '<span class="' + this.options.wrap_title.title_class + '">' + this.title + '</span>';
      var value = '';

      var values_group;

      if (!this.options.hide_selected) {
        var separator = this.$operator.val() == '><' ? ' ' + this.options.msg.and : ',';

        values_group = this.current_values_group();
        values_group.each($.proxy(function (index, item) {
          var vl = '';
          try {
            if (item.tagName == "SELECT") {
              vl = item.options && item.options.length > 0 ? item.options[item.selectedIndex].text : '';
            }
            else if (item.tagName == 'INPUT' && (item.type == 'checkbox' || item.type == 'radio')) {
              if (item.checked && item.parentNode) {
                vl = item.parentNode.getElementsByClassName(this.options.value_item_text_class)[0].textContent;
              }
            }
            else {
              vl = item.value;
            }

            if (vl != '' && vl != ' ') {
              value += value.length > 0 ? separator + ' ' + vl : vl;
            }
          }
          catch (e) {
          }
        }, this));
      }

      var operator = this.$operator.find('option:selected:first').text();

      if (value || (operator && values_group && values_group.length == 0 && !this.options.ajaxable)) {
        html += '<span class="' + this.options.wrap_title.dots_class + '">: </span>';
        if (this.options.operator_title_first) {
          html += '<span class="' + this.options.wrap_title.operator_class + '">' + operator + '</span> ';
          if (value) {
            html += '<span class="' + this.options.wrap_title.values_class + '">' + value + '</span>';
            this.$element.attr('title', this.title + ': ' + operator + ' ' + value);
          } else {
            this.$element.attr('title', this.title + ': ' + operator);
          }
        } else {
          if (value) {
            html += '<span class="' + this.options.wrap_title.values_class + '">' + value + '</span> ';
            this.$element.attr('title', this.title + ': ' + value + ' ' + operator);
          } else {
            this.$element.attr('title', this.title + ': ' + operator);
          }
          html += '<span class="' + this.options.wrap_title.operator_class + '">' + operator + '</span>';
        }
      } else {
        this.$element.attr('title', this.title);
      }

      html += '</span>';

      this.$element.prepend(html);
    },

    open: function() {
      if (this.visible) {
        return false;
      } else {
        this.$element.addClass('open');
        this.visible = true;
        this.$element.trigger('opened');
      }
    },
    close: function() {
      this.$element.modal_window('hide');
      return false;
    },
    remove: function() {
      this.$element.modal_window('destroy');
      this.$element.trigger('removing');
      this.$element.remove();
      this.$modal.remove();
      return false;
    },


    current_values_group: function() {
      return this.$values_container.filter('[style!="display:none;"][style!="display: none;"]')
                                   .find('.' + this.options.values_container.data_group_class)
                                   .filter('[style!="display:none;"][style!="display: none;"]')
                                   .find('.' + this.options.value_class)
                                   .not('.' + this.options.search_field_class);
    },

    set_no_match_visibility: function() {
      if (this.options.ajaxable) {
        this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class + ' .eq-init-msg').show();
        this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class + ' .eq-search-msg').hide();
      }

      if (this.current_values_group().closest('li:not(.' + this.options.out_search_class + '):not(.' + this.options.hidden_selected_class + ')').length == 0) {
        if (this.options.ajaxable && this.$search_field.val().length == 0) {
          this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class).removeClass(this.options.out_search_class);
          this.$values_container.find('.' + this.options.values_container.no_matches_item_class).addClass(this.options.out_search_class);
        } else {
          this.$values_container.find('.' + this.options.values_container.no_matches_item_class).removeClass(this.options.out_search_class);
          this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class).addClass(this.options.out_search_class);
        }
      } else {
        if (this.options.ajaxable && this.$search_field.val().length == 0) {
          this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class).removeClass(this.options.out_search_class);
        } else {
          this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class).addClass(this.options.out_search_class);
        }
        this.$values_container.find('.' + this.options.values_container.no_matches_item_class).addClass(this.options.out_search_class);
      }
    },
    set_clear_values_link_visibility: function() {
      if (!this.filtered && !this.options.hide_selected && this.options.data && this.options.data.v && this.options.data.v.length > 0) {
        this.$clear_values_link.closest('li').removeClass(this.options.out_search_class);
      } else {
        this.$clear_values_link.closest('li').addClass(this.options.out_search_class);
      }
    },
    set_values_group_visibility: function() {
      var operator = this.$operator.val();
      this.$values_container.hide();
      var items = this.$values_container.find('.' + this.options.values_container.data_group_class)
                      .hide()
                      .filter(function() {
                        return !operator || (this.getAttribute('data-operators') || '').split(',').indexOf(operator) >= 0;
                      });
      if (items.length > 0) {
        this.$values_container.show();
        items.show();
      }

      this.clear_values();
    },
    reset_button: function() {
      var operator;
      var values = [];
      if (this.options.data) {
        operator = this.options.data.e || '';
        values = this.options.data.v || [];
      }
      if (!operator) {
        operator = this.$operator.find('option:first').attr('value');
      }

      this.$operator.val(operator);
      this.set_values_group_visibility();

      if (this.options.ajaxable) {
        if (this.ajax) {
          this.ajax.abort();
          this.ajax = null;
        }
      }

      this.current_values_group().removeAttr('data-selected').closest('li:not(.' + this.options.out_search_class + ')').removeClass(this.options.hidden_selected_class);

      this.current_values_group()
          .each($.proxy(function(index, item) {
            if (item.tagName == 'INPUT' && (item.type == 'checkbox' || item.type == 'radio')) {
              if (this.options.hide_selected && values.indexOf(item.value) >= 0) {
                item.checked = false;
                item.setAttribute('data-selected', 1);
                $(item).closest('li').addClass(this.options.hidden_selected_class);
              } else {
                item.checked = values.indexOf(item.value) >= 0;
              }
            }
            else { item.value = values[index] || ''; }
          }, this));

      if (this.options.ajaxable) {
        this.current_values_group().not(':checked').closest('li').remove();
      }

      if (this.filtered) {
        this.reset_search();
      } else {
        this.set_clear_values_link_visibility();
        this.set_no_match_visibility();
      }
      this.build_title();
    },
    reset_search: function() {
      if (!this.filtered) { return; }

      this.$search_field.val('');
      this.filtered = false;
      if (this.options.ajaxable) {
        this.current_values_group().not(':checked').closest('li').remove();
      }
      this.$values_container.find('.' + this.options.search_field_class).val('');

      this.current_values_group().closest('li')
          .removeClass(this.options.out_search_class)
          .find('.' + this.options.value_item_text_class)
          .each(function(index, item) {
            item.innerHTML = this.getAttribute('data-text');
          });

      this.set_no_match_visibility();
      this.set_clear_values_link_visibility();
    },
    save_button: function() {
      this.options.data = this.options.data || { e: '', v: [] };
      this.options.data.e = this.$operator.val() || '';
      var values = [];
      if (this.options.ajaxable) {
        this.current_values_group().not(':checked').closest('li').remove();
      }
      this.current_values_group()
          .each($.proxy(function (index, item) {
            try {
              if (item.tagName == 'SELECT') {
                values.push(item.value);
              } else if (item.tagName == 'INPUT' && (item.type == 'checkbox' || item.type == 'radio')) {
                if (item.checked || (this.options.hide_selected && item.getAttribute('data-selected') == '1')) {
                  values.push(item.value);
                }
              } else if (item.value && item.value != '' && item.value != ' ') {
                values.push(item.value);
              }
            }
            catch (e) { }
          }, this));

      this.options.data.v = values;
      this.$element.trigger('saved');
    },
    search: function(value) {
      if (this.old_search && this.old_search == value) { return; }
      this.old_search = value;

      value = (value || '').toString().toLowerCase();

      if (!value || value == '' || value.length == 0) {
        this.reset_search();
        return;
      }
      this.filtered = true;


      if (this.options.ajaxable) {
        this.ajax_loading = true;
        this.current_values_group().not(':checked').closest('li').remove();
        this._search(value);

        if (this.ajax) {
          this.ajax.abort();
          this.ajax = null;
        }
        this.$values_container.find('.' + this.options.values_container.no_matches_item_class).addClass(this.options.out_search_class);
        this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class).removeClass(this.options.out_search_class);
        this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class + ' .eq-init-msg').hide();
        this.$values_container.find('.' + this.options.values_container.no_matches_ajax_item_class + ' .eq-search-msg').show();
        var vls = this.current_values_group().map(function() { return this.value; }).get();

        this.ajax = $.ajax({
          type: 'GET',
          url: this.ajax_url,
          data: { q: value },
          dataType: 'json',
          context: this
        }).success(function(data) {
          var html = '';
          if (data && data.length > 0) {
            for (var sch = 0; sch < data.length; sch++) {
              var vl = data[sch];
              if (vls.indexOf(vl[1].toString()) >= 0) { continue; }
              html += '<li class="eq-filter-list-item"><label>';
              html += '<input type="checkbox" name="eq-values[]" value="' + vl[1] + '" id="eq-value-' + this.field + '-' + vl[1] + '" class="eq-value">';
              html += '<span class="eq-value-text" data-text="' + vl[0] + '">' + vl[0] + '</span>';
              html += '</label></li>';
            }
            this.$values_container.find('#eq-filter-list-' + this.field).append(html);
            this._search(value);
          }
        });
      } else {
        this._search(value);
      }
    },
    clear_values: function() {
      this.current_values_group().filter('[type!="checkbox"][type!="radio"]').val('');
      this.current_values_group().filter('input[type="checkbox"], input[type="radio"]').prop('checked', false);
      this.current_values_group().filter('select').prop('selectedIndex', 0);
      this.$clear_values_link.closest('li').addClass(this.options.out_search_class);
      this.set_no_match_visibility();
      this.modal_shown_handler();
    },
    _search: function(value) {
      this.current_values_group().closest('li').each($.proxy(function(index, item) {
        var hide = false;
        if ((' ' + item.className + ' ').replace(/[\n\t]/g, ' ').indexOf(' ' + this.options.values_container.item_class + ' ' ) >= 0) {
          var text_container = item.getElementsByClassName(this.options.value_item_text_class);
          if (text_container) { text_container = text_container[0]; }
          if (!text_container) { return; }

          var text = text_container.textContent;
          var ind = text.toLowerCase().indexOf(value);
          var html = '';
          if (ind >= 0) {
            html = text.substring(0, ind);
            html += '<em>' + text.substring(ind, ind + value.length) + '</em>';
            if (ind + value.length < text.length) {
              html += text.substring(value.length + ind);
            }
            text_container.innerHTML = html;
          } else {
            hide = true;
          }
        } else {
          hide = true;
        }

        if (hide) {
          if ((' ' + item.className + ' ').replace(/[\n\t]/g, ' ').indexOf(' ' + this.options.out_search_class + ' ' ) < 0) {
            item.className += ' ' + this.options.out_search_class;
          }
        } else {
          item.className = (' ' + item.className + ' ').replace(/[\n\t]/g, ' ').replace(' ' + this.options.out_search_class + ' ', '').replace(/^\s+|\s{2,}|\s+$/g, '');
        }
      }, this));

      this.set_clear_values_link_visibility();
      this.set_no_match_visibility();
    }
  };


  $.fn.eq_button = function(option) {
    return this.each(function() {
      var $this = $(this)
          , data = $this.data('eq_button')
          , options = typeof option == 'object' && option;
      if (!data) { $this.data('eq_button', (data = new eq_button(this, options))); }
      if (typeof option == 'string') { data[option](); }
    })
  };

  $.fn.eq_button.defaults = {
    data: undefined,
    hide_selected: false,
    can_delete: true,
    operator_title_first: true,
    just_search: false,
    ajaxable: false,
    caret_class: 'eq-caret',
    delete_class: 'eq-filter-delete',
    wrap_title: {
      class: 'eq-filter-wrap',
      title_class: 'eq-field-title',
      dots_class: 'eq-field-dots',
      operator_class: 'eq-field-operator',
      values_class: 'eq-field-values'
    },
    operator_container_class: 'eq-filter-operator',
    values_container: {
      class: 'eq-filter-data',
      clear_class: 'eq-filter-list-clear',
      data_group_class: 'eq-filter-data-item',
      items_list_class: 'eq-filter-list',
      item_class: 'eq-filter-list-item',
      no_matches_item_class: 'eq-no-matches',
      no_matches_ajax_item_class: 'eq-no-matches-ajax'
    },
    operator_class: 'eq-operator',
    value_item_text_class: 'eq-value-text',
    search_field_class: 'eq-search',
    modal_buttons: {
      class: 'eq-filter-buttons',
      buttons_save_class: 'eq-save',
      buttons_cancel_class: 'eq-cancel'
    },
    msg: {
      and: 'и',
      delete_filter: 'Удалить фильтр',
      button_save: 'Сохранить',
      button_cancel: 'Отмена'
    },
    button_class: 'eq-button',
    button_small_class: 'eq-button-small',
    button_success_class: 'eq-button-success',
    out_search_class: 'eq-out-search',
    hidden_selected_class: 'eq-hidden-selected',
    value_class: 'eq-value',
    value_name_start: 'eq-values',
    ajaxable_class: 'eq-ajaxable'
  };

  $.fn.eq_button.Constructor = eq_button;
} (window.jQuery);


RMPlus.EQ = (function (my) {
  var my = my || {};

  my.query_class = '';
  my.custom_query_page_enabled = 0;
  my.custom_query_timelog_page_enabled = 0;
  my.label_and = '';
  my.label_delete_filter = '';
  my.label_save_button = '';
  my.label_cancel_button = '';
  my.sort_label = '';
  my.standalone_operators = undefined;
  my.saved_data = undefined;
  my.query_form_content_html = '';
  my.buttons_html = '';

  my.project_id = '';
  my.saved_query_id = 0;

  my.add_filter_button = function(url, fields) {
    $.ajax({
      type: 'GET',
      url: url,
      data: { fields: fields },
      dataType: 'text html'
    }).done(function(data) {
      if (!data) { return; }
      data = $(data);
      var $data = data.filter('a.eq-filter-button');
      var fields = $('#eq-filters').find('.eq-filters-table .eq-filter-button').map(function() { return this.getAttribute('data-field'); }).get();
      if (fields && fields.length > 0) {
        $data = $data.filter('[data-field!="' + fields.join('"][data-field!="') + '"]');
      }

      if ($data.length > 0) {
        $('#eq-filters').find('.eq-filters-table td .eq-user').append(data);
        $data.eq_button({ can_delete: true,
                          hide_selected: false,
                          msg: { and: my.label_and,
                                 delete_filter: my.label_delete_filter,
                                 button_save: my.label_save_button,
                                 button_cancel: my.label_cancel_button
                               }
                        });
        $(document.body).prepend(data.find('div.modal_window'));

        if($().periodpicker){
          data.find('.eq-date-value').periodpicker(periodpickerOptions);
          data.find('.eq-periodpicker-value').periodpicker(datetimepickerOptions);
        }else{
          data.find('.eq-date-value').datepicker(datepickerOptions);
        }
      }
    }).fail(function() {
      var $obj = $(document.body).data('ajax_emmiter');
      if ($obj) {
        $("div.loader:empty").remove();
        $obj.show();
      }
    });
  };
  my.add_sort_button = function() {
    var sort_index = $('.eq-panel.eq-sort-items:first').find('.eq-another-button').length;
    var $item = $('#f-sort_by_0').clone().html('').removeData('modal_window').removeClass('mw-link');
    $item.attr('id', 'f-sort_by_' + sort_index)
         .attr('data-field', 'sort_by_' + sort_index)
         .attr('title', my.sort_label);
    var $add_sort_link = $('#eq-add-sort');
    $add_sort_link.before(' ');
    $add_sort_link.before($item);
    var $modal = $('#modal-f-sort_by_0').clone().attr('id', 'modal-f-sort_by_' + sort_index).removeData('modal_window');
    $modal.find('input[name="eq-valuessort-0[]"]').attr('name', 'eq-valuessort-' + sort_index + '[]');
    $(document.body).prepend($modal);

    $item.eq_button({ can_delete: true,
                      hide_selected: false,
                      operator_title_first: false, data: { e: '', v: [] },
                      msg: {
                        and: RMPlus.EQ.label_and,
                        delete_filter: RMPlus.EQ.label_delete_filter,
                        button_save: RMPlus.EQ.label_save_button,
                        button_cancel: RMPlus.EQ.label_cancel_button
                      }
    });

    if (sort_index >= 2) {
      $add_sort_link.hide();
    }
  };

  my.generate_hidden_input = function(name, value) {
    return $('<input type="hidden" name="' + name + '">').val(value);
  };
  my.prepare_query_form = function(save_query) {
    var buttons = $('a.eq-filter-button, a.eq-another-button').map(function() { return $(this).data('eq_button'); }).get();
    var $form = $('#query_form');
    $form.find('#query_form_with_buttons').html('');
    $form.append(my.generate_hidden_input('set_filter', 1));
    var sort_item_index = 0;
    for (var sch = 0; sch < buttons.length; sch ++) {
      if (!buttons[sch] || !buttons[sch].options || !buttons[sch].options.data) { continue; }
      var field = buttons[sch].field;
      var data = buttons[sch].options.data;

      if (buttons[sch].$element.hasClass('eq-filter-button')) {
        if (!data.e && (!data.v || data.v.length == 0)) { continue; }

        if ((!my.standalone_operators || my.standalone_operators.indexOf(data.e) < 0) && (!data.v || data.v.length == 0)) { continue; }

        $form.append(my.generate_hidden_input('f[]', field));
        $form.append(my.generate_hidden_input('op[' + field + ']', data.e));

        if (my.standalone_operators && my.standalone_operators.indexOf(data.e) >= 0) { continue; }

        for (var sch2 = 0; sch2 < data.v.length; sch2 ++) {
          $form.append(my.generate_hidden_input('v[' + field + '][]', data.v[sch2] || ''));
        }
      } else if (field.indexOf('sort_by') == 0) {
        if (!data.e || !data.v || data.v.length != 1) {
          continue;
        }
        $form.append(my.generate_hidden_input('sort_criteria[' + sort_item_index + '][]', data.v[0]));
        $form.append(my.generate_hidden_input('sort_criteria[' + sort_item_index + '][]', data.e));
        sort_item_index += 1;
      } else if (field == 'show' || field == 'totalable') {
        for (var sch3 = 0; sch3 < data.v.length; sch3 ++) {
          $form.append(my.generate_hidden_input(field == 'show' ? 'c[]' : 't[]', data.v[sch3]));
        }
      } else if (field == 'group_by') {
        if (!data.v || data.v.length != 1) { continue; }
        $form.append(my.generate_hidden_input('query[group_by]', data.v[0]));
      } else {
        if (!data.v || data.v.length == 0) { continue; }
        for (var sch2 = 0; sch2 < data.v.length; sch2 ++) {
          $form.append(my.generate_hidden_input('query[' + field + '][]', data.v[sch2] || ''));
        }
      }
    }

    // fix for IE... fuck
    $('#eq-columns-container').find('input.eq-value').each(function() {
      $form.append(my.generate_hidden_input('c[]', this.value));
    });
    if (save_query) {
      $form.append(my.generate_hidden_input('saved_query_id', my.saved_query_id));
    }
    return $form;
  };

  my.patch_filters_panel = function() {
    if (my.query_class == 'IssueQuery' && my.custom_query_page_enabled != 1) { return; }
    if (my.query_class == 'TimeEntryQuery' && my.custom_query_timelog_page_enabled != 1) { return; }

    var $query_form = $('#query_form_content');
    var $buttons = $('#query_form_with_buttons').find('p.buttons');
    $query_form.html('').append(my.query_form_content_html);
    $buttons.html('').append(my.buttons_html).css('margin-top', '5px');
    $('#query_form').before($query_form).before($buttons);

    if ($('#query_form_content').length > 0) {
      $('.contextual .icon-edit, .contextual .icon-del').remove();
    }
  };
  my.initialize_buttons = function() {
    if (my.query_class == 'IssueQuery' && my.custom_query_page_enabled != 1) { return; }
    if (my.query_class == 'TimeEntryQuery' && my.custom_query_timelog_page_enabled != 1) { return; }
    var sort_index = 0;
    $('a.eq-filter-button, a.eq-fields-button, a.eq-another-button').each(function() {
      var $this = $(this);
      var is_sort = $this.attr('data-field').indexOf('sort_by') == 0;

      $this.eq_button({ can_delete: $this.hasClass('eq-filter-button') || (is_sort && sort_index > 0),
                        hide_selected: $this.hasClass('eq-fields-button'),
                        operator_title_first: !is_sort,
                        data: RMPlus.EQ.saved_data[$this.attr('data-field')],
                        msg: { and: RMPlus.EQ.label_and,
                          delete_filter: RMPlus.EQ.label_delete_filter,
                          button_save: RMPlus.EQ.label_save_button,
                          button_cancel: RMPlus.EQ.label_cancel_button
                        }
      });

      if (is_sort) {
        sort_index ++;
      }

    });

    $('#eq-available-fields, #eq-selected-fields').eq_button({ just_search: true });
    $(document.body).prepend($('div.modal_window'));
  };

  my.pinning = function(selector, is_delete, new_url, new_title) {
    var li = $(selector);
    if (li.length == 0) { return; }

    var offset = li.position( );
    var dest = li.parents('ul:first');

    if (is_delete) {
      $('#' + li.attr('id').replace('pinned-', '') + ' a.eq-pinning').toggleClass('eq-unpin').toggleClass('eq-pin').attr('title', new_title).attr('href', new_url);
    }
    else {
      li.find('a.eq-pinning').toggleClass('eq-unpin').toggleClass('eq-pin').attr('title', new_title).attr('href', new_url);
      li = li.clone( );
      li.attr('id', 'pinned-' + li.attr('id'));
      dest.append(li);
    }

    li.css('position', 'absolute')
        .css('top', offset.top)
        .css('left', offset.left)
        .css('width', li.width( ))
        .animate({ top: offset.top - (is_delete ? -100 : 100),
          opacity: 0,
        }, 300, 'swing', function( ) {
          var $this = $(this);
          $this.remove( ).removeAttr('style');
          if (is_delete) {
            if ($('#eq-sidebar-pinned-queries ul li').length == 0) { $('#eq-sidebar-pinned-queries').hide( ); }
          }
          else {
            var fieldset = $('#eq-sidebar-pinned-queries').show( );
            if ((ul = fieldset.find('ul')).length == 0) {
              fieldset.append('<ul></ul>');
              ul = fieldset.find('ul');
            }
            ul.append($this);
            $this.effect('highlight');
          }
        });
  };

  return my;
})(RMPlus.EQ || {});

$(document).ready(function() {
  RMPlus.EQ.patch_filters_panel();
  RMPlus.EQ.initialize_buttons();


  $('.eq-date-value').datepicker(datepickerOptions);
  $('#eq-columns-container').sortable({ items: 'li.eq-filter-list-item', revert: true, axis: 'y' });
  $('#query_form #criterias').removeAttr('onchange');

  if($().periodpicker){
    $('.eq-date-value').removeClass('hasDatepicker').periodpicker(periodpickerOptions);
    $('.ui-datepicker-trigger').remove();
    $('.eq-periodpicker-value').periodpicker(datetimepickerOptions);
  }


  $(document.body).on('removing', 'a.eq-filter-button', function() {
    var field_button = $('a.eq-fields-button').data('eq_button');
    var values = field_button.options.data.v || [];
    var ind = values.indexOf(this.getAttribute('data-field'));
    if (ind >= 0) {
      values.splice(ind, 1);
    }
    field_button.options.data.v = values;
    field_button.reset_button();
  });

  $('a.eq-fields-button').on('saved', function() {
    var $this = $(this);
    $(document.body).data('ajax_emmiter', $this);
    var fields = $this.data('eq_button').$values_container.find('input:checked').map(function() { return this.value; }).get();
    RMPlus.EQ.add_filter_button($this.attr('data-url'), fields);
  });

  $('#eq-add-sort').on('click', function() {
    RMPlus.EQ.add_sort_button();
    return false;
  });

  $(document.body).on('removing', '.eq-panel.eq-sort-items a.eq-another-button', function() {
    $('#eq-add-sort').show();
  });

  $(document.body).on('click', '.eq-add-column, .eq-delete-column', function() {
    var btn = $(this);
    var table = btn.parents('table:first');
    var dest = btn.hasClass('eq-delete-column') ? table.find('.eq-available-columns-container .eq-filter-list') : table.find('.eq-columns-container .eq-filter-list');
    var source = btn.hasClass('eq-delete-column') ? table.find('.eq-columns-container .eq-filter-list') : table.find('.eq-available-columns-container .eq-filter-list');

    var source_btn = source.closest('td').data('eq_button');
    var dest_btn = dest.closest('td').data('eq_button');
    source_btn.filtered = true;
    source_btn.$search_field.val('').trigger('change');
    dest_btn.filtered = true;
    dest_btn.$search_field.val('').trigger('change');
    source.find('input:checked').each(function() {
      var $this = $(this);
      var li = $this.parents('li:first').clone();
      $this.parents('li:first').remove();

      li.find('input').prop('checked', false);
      dest.append(li.removeClass('eq-out-search'));
    });

    if (btn.hasClass('eq-delete-column')) {
      var arr = [],
          list = dest.get(0),
          childs = list.children;
      for (var sch = 0; sch < childs.length; sch ++) { arr[sch] = childs[sch]; }

      arr.sort(function(a, b) { if (a.textContent == b.textContent) { return 0; } return a.textContent < b.textContent ? -1 : 1; });
      for (var sch = 0; sch < childs.length; sch ++) { list.appendChild(arr[sch]); }
    }

    source_btn.filtered = true;
    source_btn.$search_field.val('').trigger('change');
    dest_btn.filtered = true;
    dest_btn.$search_field.val('').trigger('change');

    return false;
  });

  $('#eq-apply-query').click(function() {
    RMPlus.EQ.prepare_query_form(true).attr('action', this.href).submit();

    return false;
  });


  $('#eq-query-save-as, #eq-query-save').click(function() {
    var $modal = $('#eq-query-modal');
    if ($modal.length == 0) {
      $modal = $('<div id="eq-query-modal" class="modal I fade" role="dialog" aria-hidden="true" data-width="950px" data-height="90%" style="z-index: 1061;"></div>');
      $(document.body).prepend($modal);
    }
    var url = this.href + '&' + RMPlus.EQ.prepare_query_form(this.id == 'sd-query-save').serialize();
    $modal.html('<div class="big_loader form_loader"></div>')
          .modal('show')
          .load(url, function() {
            RMPlus.LIB.resize_bs_modal(this);
          });
    return false;
  });

  $(document.body).on('change', '#criterias, #columns', function() {
    $('#eq-apply-query').trigger('click');
  });

  $('#tab-content-query_settings input[name="query[visibility]"]').change(function() {
    var checked = $('#query_visibility_1').is(':checked');
    $("input[name='query[role_ids][]'][type=checkbox]").prop('disabled', !checked);
  }).trigger('change');

  $('fieldset.eq-sidebar-taggable-fieldset legend a').click(function() {
    var $this = $(this);
    var $fieldset = $this.parents('fieldset:first');
    var expanded = $fieldset.hasClass('expanded');
    var inner_div = $fieldset.find('div:first');

    if (expanded) { inner_div.hide(); }
    else if (inner_div.length != 0) { inner_div.show(); }
    var need_to_load = !expanded && inner_div.length == 0;
    if (need_to_load) { $fieldset.addClass('loading'); }
    else { $fieldset.toggleClass('expanded'); }
    $.ajax({
      type: 'GET',
      url: this.href,
      data: { expand: need_to_load ? 1 : undefined,
              status: expanded ? undefined : 1
      }
    }).done(function(html) {
      if (need_to_load) {
        $fieldset.toggleClass('expanded');
        $fieldset.append(html);
      }
    }).always(function() {
      $fieldset.removeClass('loading');
    });

    return false;
  });

  $('#eq-sidebar-pinned-queries ul').sortable({
    revert: true,
    cursor: 'move',
    opacity: 0.6,
    delay: 250,
    update: function() {
      var data = $(this).sortable('serialize');
      $.ajax({
        type: 'POST',
        data: data,
        url: $('#eq-sidebar-pinned-queries').attr('data-url')
      });
    }
  });
  if($().periodpicker) {
    $(document.body).on('change', 'div.eq-filter-field select.eq-operator', function () {
      var filter = $(this).parents('div.modal_window.eq-filter-field');
      filter.find('.eq-date-value.eq-value').periodpicker('change');
      filter.find('.eq-periodpicker-value.eq-value').periodpicker('change');
    });
  }
});


