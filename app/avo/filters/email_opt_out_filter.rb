class Avo::Filters::EmailOptOutFilter < Avo::Filters::BooleanFilter
  self.name = 'Email Notifications'

  def apply(request, query, values)
    return query if values[:opted_out].nil?

    query.where(email_notifications_opted_out: values[:opted_out])
  end

  def options
    {
      opted_out: 'Opted Out of Email Notifications'
    }
  end
end
