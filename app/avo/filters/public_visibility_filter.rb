class Avo::Filters::PublicVisibilityFilter < Avo::Filters::BooleanFilter
  self.name = 'Public Visibility'

  def apply(request, query, values)
    return query if values[:public_visibility].nil?

    query.where(public_visibility: values[:public_visibility])
  end

  def options
    {
      public_visibility: 'Public Visibility'
    }
  end
end
