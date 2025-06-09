require 'rails_helper'

RSpec.describe 'Avo Integration', type: :request do
  let(:user) { create(:user) }
  let(:house) { create(:house) }
  let(:resident) { create(:resident, house: house) }

  describe 'Avo Dashboard' do
    context 'when authenticated' do
      before do
        post user_session_path, params: { user: { email: user.email, password: user.password } }
      end

      it 'renders the avo dashboard' do
        get '/avo'
        # Avo redirects to the first resource by default
        expect(response).to redirect_to('/avo/resources/houses')
      end
    end

    context 'when not authenticated' do
      it 'redirects to sign in for avo dashboard' do
        get '/avo'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'Houses Admin' do
    before do
      post user_session_path, params: { user: { email: user.email, password: user.password } }
    end

    it 'lists houses' do
      house # create the house
      get '/avo/resources/houses'
      expect(response).to have_http_status(:success)
      expect(response.body).to include(house.street_name)
    end

    it 'supports searching houses by street name' do
      house # create the house
      get '/avo/resources/houses', params: { q: house.street_name }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(house.street_name)
    end

    it 'shows a house' do
      get "/avo/resources/houses/#{house.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(house.street_name)
    end

    it 'renders the new house form' do
      get '/avo/resources/houses/new'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Street name')
    end
  end

  describe 'Residents Admin' do
    before do
      post user_session_path, params: { user: { email: user.email, password: user.password } }
    end

    it 'lists residents' do
      resident # create the resident
      get '/avo/resources/residents'
      expect(response).to have_http_status(:success)
      expect(response.body).to include(resident.official_name)
    end

    it 'supports searching residents by name' do
      resident # create the resident
      get '/avo/resources/residents', params: { q: resident.official_name }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(resident.official_name)
    end

    it 'shows a resident' do
      get "/avo/resources/residents/#{resident.id}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(resident.official_name)
    end

    it 'renders the new resident form' do
      get '/avo/resources/residents/new'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Official name')
    end

    describe 'ResidentStatusFilter' do
      let(:filter) { Avo::Filters::ResidentStatusFilter.new }
      let(:base_query) { instance_double('ActiveRecord::Relation') }
      let(:where_query) { instance_double('ActiveRecord::Relation') }
      let(:where_not_query) { instance_double('ActiveRecord::Relation') }

      it 'filters for current residents' do
        allow(base_query).to receive(:where).with(last_seen_at: nil, hidden: [ false, nil ]).and_return([ 'current_resident' ])

        result = filter.apply(nil, base_query, [ 'current' ])
        expect(result).to eq([ 'current_resident' ])
      end

      it 'filters for past residents' do
        # Stub the where.not chain by allowing base_query to return the final result directly
        allow(base_query).to receive_message_chain(:where, :not).with(no_args).with(last_seen_at: nil).and_return([ 'past_resident' ])

        result = filter.apply(nil, base_query, [ 'past' ])
        expect(result).to eq([ 'past_resident' ])
      end

      it 'filters for hidden residents' do
        allow(base_query).to receive(:where).with(hidden: true).and_return([ 'hidden_resident' ])

        result = filter.apply(nil, base_query, [ 'hidden' ])
        expect(result).to eq([ 'hidden_resident' ])
      end

      it 'filters for active residents' do
        allow(base_query).to receive(:where).with(hidden: [ false, nil ]).and_return([ 'active_resident' ])

        result = filter.apply(nil, base_query, [ 'active' ])
        expect(result).to eq([ 'active_resident' ])
      end

      it 'returns original query for unknown values' do
        result = filter.apply(nil, base_query, [ 'unknown' ])
        expect(result).to eq(base_query)
      end

      it 'returns original query for blank values' do
        result = filter.apply(nil, base_query, [])
        expect(result).to eq(base_query)
      end

      it 'has correct options' do
        expected_options = {
          'active' => 'Active',
          'hidden' => 'Hidden',
          'current' => 'Current Residents',
          'past' => 'Past Residents'
        }
        expect(filter.options).to eq(expected_options)
      end
    end

    describe 'EmailOptOutFilter' do
      let(:filter) { Avo::Filters::EmailOptOutFilter.new }
      let(:base_query) { instance_double('ActiveRecord::Relation') }

      it 'filters for opted out residents' do
        allow(base_query).to receive(:where).with(email_notifications_opted_out: true).and_return([ 'opted_out_resident' ])

        result = filter.apply(nil, base_query, { opted_out: true })
        expect(result).to eq([ 'opted_out_resident' ])
      end

      it 'filters for subscribed residents' do
        allow(base_query).to receive(:where).with(email_notifications_opted_out: false).and_return([ 'subscribed_resident' ])

        result = filter.apply(nil, base_query, { opted_out: false })
        expect(result).to eq([ 'subscribed_resident' ])
      end

      it 'returns original query for nil values' do
        result = filter.apply(nil, base_query, { opted_out: nil })
        expect(result).to eq(base_query)
      end

      it 'returns original query for missing key' do
        result = filter.apply(nil, base_query, {})
        expect(result).to eq(base_query)
      end

      it 'has correct options' do
        expected_options = {
          opted_out: 'Opted Out of Email Notifications'
        }
        expect(filter.options).to eq(expected_options)
      end
    end
  end
end
