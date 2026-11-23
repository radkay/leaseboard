module ApplicationHelper
  # A status label in the DESIGN.md palette, always paired with its text (color is
  # never the only signal). Matches the `.status--<name>` classes in application.css.
  def status_pill(status)
    tag.span(status.to_s.humanize, class: "status status--#{status}")
  end

  # Currency without cents for the admin tables: 1434 -> "$1,434". Blank when nil.
  def money(amount)
    return if amount.nil?

    number_to_currency(amount, precision: 0)
  end

  # A readable date for the admin tables: "Jan 5, 2027". Blank when nil.
  def pretty_date(date)
    date&.strftime("%b %-d, %Y")
  end
end
