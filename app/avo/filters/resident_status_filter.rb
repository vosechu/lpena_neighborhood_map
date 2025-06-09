class Avo::Filters::ResidentStatusFilter < Avo::Filters::SelectFilter
  self.name = 'Status'

  def apply(request, query, value)
    return query if value.blank?

    case value
    when 'active'
      query.where(hidden: [ false, nil ])
    when 'hidden'
      query.where(hidden: true)
    when 'current'
      query.where(last_seen_at: nil, hidden: [ false, nil ])
    when 'past'
      query.where.not(last_seen_at: nil)
    else
      query
    end
  end

  def options
    {
      'active' => 'Active',
      'hidden' => 'Hidden',
      'current' => 'Current Residents',
      'past' => 'Past Residents'
    }
  end
end
