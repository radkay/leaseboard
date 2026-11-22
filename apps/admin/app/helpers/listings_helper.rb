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

  # Palette colors (docs/DESIGN.md) for the abstract listing-hero gradient that stands in
  # for a photo and carries the property name. Deep green, teal, ink, sage, terracotta, ochre.
  ART_COLORS = %w[#1f5c3d #246e73 #2e3a46 #516b48 #9c4a2f #8a5a12].freeze

  # A deterministic two-color gradient per property, so the three listings differ.
  def listing_art_style(property)
    a = ART_COLORS[property.id % ART_COLORS.length]
    b = ART_COLORS[(property.id + 2) % ART_COLORS.length]
    "--art-a: #{a}; --art-b: #{b};"
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
