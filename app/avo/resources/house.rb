class Avo::Resources::House < Avo::BaseResource
  self.includes = [ :residents ]

  # Enable search across multiple fields
  self.search = {
    query: -> {
      query.ransack(
        street_number_eq: params[:q],
        street_name_cont: params[:q],
        city_cont: params[:q],
        state_cont: params[:q],
        zip_cont: params[:q],
        pcpa_uid_cont: params[:q],
        m: 'or'
      ).result(distinct: false)
    }
  }

  def fields
    field :id, as: :id, sortable: true
    field :street_number, as: :number, sortable: true
    field :street_name, as: :text, sortable: true
    field :city, as: :text, sortable: true
    field :state, as: :text, sortable: true
    field :zip, as: :text, sortable: true
    field :pcpa_uid, as: :text, sortable: true, help: 'Property Control Parcel Area UID'
    field :latitude, as: :number, format: '%.6f'
    field :longitude, as: :number, format: '%.6f'
    field :residents, as: :has_many
    field :users, as: :has_many, through: :residents
    field :boundary_geometry, as: :code, hide_on: [ :index ]
    field :last_import_at, as: :date_time, sortable: true
  end
end
