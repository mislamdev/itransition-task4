# frozen_string_literal: true

module ApplicationHelper
  # ---------------------------------------------------------------------------
  # getUniqIdValue
  #
  # IMPORTANT: this helper returns a unique DOM id. It is used for every
  # element that needs an id: the targets of the Bootstrap tooltips, the
  # "for" attribute of the labels and the "id" attribute of the inputs.
  #
  # NOTA BENE: the value is memoised per "salt" inside one request, so
  #     <label for="<%= getUniqIdValue('email') %>">   and
  #     <input id="<%= getUniqIdValue('email') %>">
  # always produce the SAME id (a label that points to nothing is broken),
  # while two different pages / requests never produce the same id.
  #
  # "automagically": the salt is derived from the name of the field, so the
  # developer only writes getUniqIdValue("email") and does not have to invent
  # or copy identifiers by hand - the CSS framework (Bootstrap) then matches
  # the label, the input and the tooltip to each other.
  # ---------------------------------------------------------------------------
  def getUniqIdValue(salt = "uniq")
    # NOTE: the per-request store, so that the same salt returns the same id.
    @get_uniq_id_values ||= {}
    key = salt.to_s
    @get_uniq_id_values[key] ||= "#{key.dasherize}-#{SecureRandom.hex(5)}"
  end

  # Small helper: the Bootstrap badge of the status column.
  # NOTE: the class comes from the model, the view only renders it.
  def status_badge(user)
    tag.span(user.status_label, class: "badge #{user.status_badge_class}")
  end

  # Small helper: the status of an account as a text with a small dot.
  #
  # IMPORTANT: the reference of the task shows the status as a plain text -
  # the dot only makes the column easier to read.
  def status_label(user)
    content_tag(:span, class: "status status-#{user.status_label.downcase}") do
      safe_join([content_tag(:i, nil, class: "status-dot"), user.status_label])
    end
  end

  # Small helper: a relative time ("5 minutes ago").
  #
  # NOTE: the reference of the task shows the last activity as a relative
  # time, the exact timestamp is in the tooltip of the cell.
  def relative_time(time)
    return "never" if time.blank?

    seconds = (Time.current - time).to_i
    seconds = 0 if seconds.negative?

    case seconds
    when 0...60      then "less than a minute ago"
    when 60...3600   then "#{count_of(seconds / 60, 'minute')} ago"
    when 3600...86_400 then "#{count_of(seconds / 3600, 'hour')} ago"
    when 86_400...604_800 then "#{count_of(seconds / 86_400, 'day')} ago"
    when 604_800...2_592_000 then "#{count_of(seconds / 604_800, 'week')} ago"
    when 2_592_000...31_536_000 then "#{count_of(seconds / 2_592_000, 'month')} ago"
    else "#{count_of(seconds / 31_536_000, 'year')} ago"
    end
  end

  # Small helper: the exact timestamp ("October 12, 2024 15:45:30") - it is
  # the content of the tooltip of the relative time.
  def exact_time(time)
    return "never" if time.blank?

    time.strftime("%B %-d, %Y %H:%M:%S")
  end

  # Small function: the number and the word ("1 minute", "5 minutes").
  def count_of(number, word)
    "#{number} #{number == 1 ? word : "#{word}s"}"
  end

  # Small helper: a readable date/time or a dash when there is no timestamp.
  # IMPORTANT: the timestamps are always shown in the same format, so that the
  # table stays aligned and comparable.
  def format_timestamp(time)
    return tag.span("—", class: "cell-muted") if time.blank?

    tag.span(time.strftime("%Y-%m-%d %H:%M"), class: "text-nowrap")
  end

  # Small helper: the link that sorts the table by a column.
  # NOTE: the direction is toggled when the column is already sorted.
  def sort_link(column, label)
    next_direction = (@sort_column == column && @sort_direction == "asc") ? "desc" : "asc"
    active = @sort_column == column

    link_to(
      url_for(sort: column, direction: next_direction, status: @status_filter, q: @query.presence),
      class: "table-sort-link #{'is-active' if active}",
      title: active ? "Sorted by #{label} (#{@sort_direction == 'asc' ? 'ascending' : 'descending'})" : "Sort by #{label}",
      "aria-label": "Sort by #{label}"
    ) do
      safe_join([
        label,
        tag.i(class: "bi bi-chevron-expand sort-icon")
      ])
    end
  end

  # Small helper: the icon that shows the sort direction.
  def sort_icon(column)
    return "" unless @sort_column == column

    @sort_direction == "asc" ? "bi-chevron-up" : "bi-chevron-down"
  end

  # Small helper: the flash messages of the request.
  # IMPORTANT: the messages are rendered as Bootstrap alerts - the application
  # never uses a browser alert().
  def flash_class(level)
    case level.to_s
    when "notice", "success" then "alert-success"
    when "alert", "error" then "alert-danger"
    when "warning" then "alert-warning"
    else "alert-info"
    end
  end
end
