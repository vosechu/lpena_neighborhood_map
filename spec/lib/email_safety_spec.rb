require 'rails_helper'

RSpec.describe 'Email Safety System' do
  let(:user) { build_stubbed(:user, email: 'real-user@gmail.com', name: 'Real User') }
  let(:resident) { build_stubbed(:resident, email: 'real-resident@gmail.com', display_name: 'Real Resident') }

  describe 'Test Environment Protection' do
    it 'blocks email delivery in test environment' do
      expect(Rails.env).to eq('test')
      expect(ActionMailer::Base.delivery_method).to eq(:test)
      expect(ActionMailer::Base.perform_deliveries).to be_falsey
    end

    it 'raises error when trying to send to real email addresses in test' do
      # Mock the UserCreationService to avoid database calls
      allow(UserCreationService).to receive(:generate_initial_login_token).and_return('test-token')

      # Create a mail with real email address
      mail = ResidentMailer.welcome_new_user(resident, user)

      expect {
        mail.deliver_now
      }.to raise_error(/EMAIL SAFETY VIOLATION.*real-user@gmail.com/)
    end

    it 'allows emails to example.com addresses in test' do
      safe_user = build_stubbed(:user, email: 'test@example.com', name: 'Test User')
      safe_resident = build_stubbed(:resident, email: 'resident@example.com', display_name: 'Test Resident')

      # Mock the UserCreationService to avoid database calls
      allow(UserCreationService).to receive(:generate_initial_login_token).and_return('test-token')

      mail = ResidentMailer.welcome_new_user(safe_resident, safe_user)

      expect {
        mail.deliver_now
      }.not_to raise_error

      # Note: Since perform_deliveries is false in test environment,
      # emails won't actually be added to the deliveries array,
      # but the safety check should pass without raising an error
      expect(mail.to).to eq([ 'test@example.com' ])
    end
  end

  describe 'EmailSafetyInterceptor' do
    let(:interceptor) { EmailSafetyInterceptor }
    let(:message) { instance_double('Mail::Message') }

    before do
      allow(message).to receive(:to).and_return([ 'user@example.com' ])
      allow(message).to receive(:subject).and_return('Test Subject')
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)
      allow(Rails.logger).to receive(:error)
    end

    context 'in test environment' do
      it 'blocks email delivery' do
        expect(message).to receive(:perform_deliveries=).with(false)

        interceptor.delivering_email(message)

        expect(Rails.logger).to have_received(:info).with('Email Safety: TEST environment - email delivery blocked')
      end
    end

    context 'in development environment' do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development')) }

      it 'logs development email handling' do
        interceptor.delivering_email(message)

        expect(Rails.logger).to have_received(:info).with('Email Safety: DEVELOPMENT environment - email redirected to file system')
      end
    end



    context 'in production environment' do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production')) }

      it 'blocks email delivery for safety' do
        expect(message).to receive(:perform_deliveries=).with(false)

        interceptor.delivering_email(message)

        expect(Rails.logger).to have_received(:warn).with('Email Safety: PRODUCTION environment - email delivery BLOCKED for safety')
      end
    end

    context 'in unknown environment' do
      before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('unknown')) }

      it 'blocks all email delivery as safety measure' do
        expect(message).to receive(:perform_deliveries=).with(false)

        interceptor.delivering_email(message)

        expect(Rails.logger).to have_received(:error).with('Email Safety: UNKNOWN environment (unknown) - blocking all email delivery as safety measure')
      end
    end
  end

  describe 'redirect_to_safe_addresses' do
    let(:message) { instance_double('Mail::Message') }
    let(:original_to) { [ 'user1@gmail.com', 'user2@yahoo.com' ] }
    let(:original_cc) { [ 'cc@gmail.com' ] }
    let(:original_body) { 'Original email body' }

    before do
      # Mock the to method to return a dup-able array
      allow(message).to receive(:to).and_return(original_to.dup)
      allow(message).to receive(:cc).and_return(original_cc&.dup)
      allow(message).to receive(:bcc).and_return(nil)
      allow(message).to receive(:subject).and_return('Test Subject')
      allow(message).to receive(:body).and_return(original_body)
      allow(message).to receive(:to=)
      allow(message).to receive(:cc=)
      allow(message).to receive(:bcc=)
      allow(message).to receive(:body=)
      allow(Rails.logger).to receive(:info)
    end

    it 'redirects recipients to safe addresses' do
      EmailSafetyInterceptor.send(:redirect_to_safe_addresses, message)

      expect(message).to have_received(:to=).with([ 'vosechu@gmail.com', 'test@example.com', 'dev@example.com' ])
      expect(message).to have_received(:cc=).with([])
      expect(message).to have_received(:bcc=).with([])
    end

    it 'includes original recipients in email body' do
      expected_body = "STAGING EMAIL REDIRECT\n" \
                      "Original recipients: TO: user1@gmail.com, TO: user2@yahoo.com, CC: cc@gmail.com\n" \
                      "Original subject: Test Subject\n\n" \
                      "---\n\n" \
                      "Original email body"

      EmailSafetyInterceptor.send(:redirect_to_safe_addresses, message)

      expect(message).to have_received(:body=).with(expected_body)
    end
  end

  describe 'Email Safety Class Existence' do
    it 'defines the EmailSafetyInterceptor class' do
      expect(EmailSafetyInterceptor).to be_a(Class)
    end

    it 'responds to delivering_email' do
      expect(EmailSafetyInterceptor).to respond_to(:delivering_email)
    end
  end
end
