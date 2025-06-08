module ApplicationHelper
  # Helper method for rendering Heroicons
  # Usage: heroicon "home", style: :outline, class: "w-5 h-5"
  # Usage: heroicon "user", style: :solid, class: "w-4 h-4 text-blue-500"
  def heroicon(name, style: :outline, **options)
    # Set default classes for consistent icon sizing
    default_classes = case style
                     when :outline
                       "w-6 h-6 stroke-current"
                     when :solid
                       "w-6 h-6 fill-current"
                     when :mini
                       "w-5 h-5 fill-current"
                     else
                       "w-6 h-6 stroke-current"
                     end

    # Merge provided classes with defaults
    css_classes = [default_classes, options[:class]].compact.join(" ")
    options[:class] = css_classes

    # Add default attributes for accessibility and styling
    options[:role] ||= "img"
    options[:aria_hidden] ||= "true"

    case style
    when :outline
      Heroicons.outline(name, **options)
    when :solid
      Heroicons.solid(name, **options)
    when :mini
      Heroicons.mini(name, **options)
    else
      Heroicons.outline(name, **options)
    end
  end

  # Convenience methods for common icon styles
  def outline_icon(name, **options)
    heroicon(name, style: :outline, **options)
  end

  def solid_icon(name, **options)
    heroicon(name, style: :solid, **options)
  end

  def mini_icon(name, **options)
    heroicon(name, style: :mini, **options)
  end
end
