module ListingsHelper
  def listing_headline(property, listing)
    listing && listing["headline"].presence || property.name
  end

  def listing_description(property, listing)
    if listing && listing["description"].present?
      render_portable_text(listing["description"])
    else
      content_tag(:p, "#{property.name} offers apartments in #{property.city}, #{property.state}.")
    end
  end

  # A minimal portable-text renderer: paragraphs and headings, bullet/number lists, and the
  # strong/em marks. Enough for listing copy without pulling in a rendering gem.
  def render_portable_text(blocks)
    return "".html_safe unless blocks.is_a?(Array)

    elements = []
    list_items = []
    list_tag = nil
    flush_list = lambda do
      next if list_tag.nil?

      elements << content_tag(list_tag, safe_join(list_items))
      list_items = []
      list_tag = nil
    end

    blocks.each do |block|
      next unless block.is_a?(Hash) && block["_type"] == "block"

      if block["listItem"].present?
        list_tag ||= block["listItem"] == "number" ? :ol : :ul
        list_items << content_tag(:li, render_spans(block["children"]))
      else
        flush_list.call
        tag = PORTABLE_HEADINGS.include?(block["style"]) ? block["style"].to_sym : :p
        elements << content_tag(tag, render_spans(block["children"]))
      end
    end
    flush_list.call

    safe_join(elements)
  end

  private

  PORTABLE_HEADINGS = %w[h1 h2 h3 h4 h5 h6].freeze

  def render_spans(children)
    return "" unless children.is_a?(Array)

    safe_join(children.map do |span|
      content = h(span["text"].to_s)
      marks = Array(span["marks"])
      content = content_tag(:strong, content) if marks.include?("strong")
      content = content_tag(:em, content) if marks.include?("em")
      content
    end)
  end
end
