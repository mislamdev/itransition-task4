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

  # Small helper: the small bar chart with the activity of an account.
  #
  # IMPORTANT: the counts come from the activity history (ActivityHistory) and
  # NOT from the model - the chart is the history of the account.
  def activity_sparkline(counts, user: nil)
    counts = Array(counts)
    total = counts.sum
    highest = counts.max.to_i

    bars = counts.map do |count|
      # NOTE: the height of a bar is the share of the biggest bar.
      height = highest.zero? ? 0 : [(count.to_f / highest) * 100, 8].max
      content_tag(:span, "", class: "spark-bar #{'is-empty' if count.to_i.zero?}",
                               style: "height: #{count.to_i.zero? ? 0 : height}%")
    end

    content_tag(:span, safe_join(bars), class: "sparkline",
                                            data: { bs_toggle: "tooltip" },
                                            title: "#{total} #{total == 1 ? 'activity' : 'activities'} in the last #{ActivityHistory::DAYS} days")
  end

  # Small helper: the designation of an account - "N/A" when there is none.
  def designation(user)
    user.position.presence || "N/A"
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
    # IMPORTANT: the column of the view is a symbol, the sorted column of the
    # controller is a string - they have to be compared as strings, otherwise
    # the active column is never marked.
    column = column.to_s
    next_direction = (sorted_column == column && @sort_direction == "asc") ? "desc" : "asc"
    active = sorted_column == column

    link_to(
      url_for(sort: column, direction: next_direction, status: @status_filter, q: @query.presence),
      class: "table-sort-link #{'is-active' if active}",
      title: active ? "Sorted by #{label} (#{@sort_direction == 'asc' ? 'ascending' : 'descending'}) - click for the other direction" : "Sort by #{label}",
      "aria-label": active ? "Sorted by #{label}, #{@sort_direction == 'asc' ? 'ascending' : 'descending'}. Click to sort the other way." : "Sort by #{label}"
    ) do
      safe_join([
        label,
        tag.i(class: "bi #{sort_icon_for(column)} sort-icon")
      ])
    end
  end

  # Small helper: the column the table is sorted by (as a string).
  def sorted_column
    @sort_column.to_s
  end

  # Small helper: the icon of the sort link.
  # IMPORTANT: the sorted column shows the direction of the order, the other
  # columns a neutral icon - the direction has to be visible at a glance.
  def sort_icon_for(column)
    return "bi-chevron-expand" unless sorted_column == column.to_s

    @sort_direction == "asc" ? "bi-chevron-up" : "bi-chevron-down"
  end

  # Small helper: the value of the attribute `aria-sort` of a column header.
  # NOTE: the screen readers announce the direction of the order.
  def aria_sort_for(column)
    return "none" unless sorted_column == column.to_s

    @sort_direction == "asc" ? "ascending" : "descending"
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
