class Avo::Resources::Resident < Avo::BaseResource
  self.includes = [ :house, :user ]

  # Enable search across multiple fields
  self.search = {
    query: -> {
      # First get the distinct IDs that match our search
      distinct_ids = query.ransack(
        official_name_cont: params[:q],
        display_name_cont: params[:q],
        email_cont: params[:q],
        phone_cont: params[:q],
        house_street_name_cont: params[:q],
        house_street_number_eq: params[:q],
        m: 'or'
      ).result.select('DISTINCT residents.id').pluck(:id)

      # Then fetch the full records for those IDs
      query.where(id: distinct_ids)
    }
  }

  # Define how the record should be displayed in search results
  self.title = :to_s

  def to_s
    record.display_name.presence || record.official_name
  end

  def fields
    # Basic Info
    field :id, as: :id, sortable: true
    field :display_name, as: :text, sortable: true
    field :official_name, as: :text, sortable: true, required: true

    # Contact Info
    field :email, as: :text, sortable: true
    field :phone, as: :text
    field :homepage, as: :text, as_html: true

    # Personal Info
    field :birthdate, as: :text, sortable: true, help: 'Format: MM-DD (e.g., 03-15 for March 15th)'
    field :welcomed_on, as: :date, sortable: true

    # Privacy Settings
    field :hide_display_name, as: :boolean
    field :hide_email, as: :boolean
    field :hide_phone, as: :boolean
    field :hide_birthdate, as: :boolean

    # Status & Visibility
    field :hidden, as: :boolean, sortable: true
    field :email_notifications_opted_out, as: :boolean

    # Additional Info
    field :skills, as: :textarea, hide_on: [ :index ]
    field :comments, as: :textarea, hide_on: [ :index ]

    # Relationships
    field :house, as: :belongs_to, searchable: true
    field :user, as: :belongs_to

    # Timestamps
    field :first_seen_at, as: :date_time, sortable: true
    field :moved_out_at, as: :date_time, sortable: true
  end

  def filters
    filter Avo::Filters::ResidentStatusFilter
    filter Avo::Filters::EmailOptOutFilter
  end
end
