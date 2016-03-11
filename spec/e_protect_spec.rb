require 'spec_helper'

describe "promoting a temporary token to a permanent token", type: :feature, js: true do
  let(:response) do
    Vantiv.tokenize(temporary_token: paypage_registration_id)
  end

  before :all do
    @test_paypage_server = Vantiv::TestPaypageServer.new
    @test_paypage_server.start
  end

  after :all do
    @test_paypage_server.stop
  end

  context "with a valid temporary token" do
    before :all do
      @card_to_tokenize = Vantiv::TestAccount.valid_account
      @paypage_registration_id = get_paypage_registration_id
    end

    let(:paypage_registration_id) { @paypage_registration_id }

    it "returns success" do
      expect(response.success?).to eq true
    end

    it "returns the permanent token (payment account id)" do
      expect(response.payment_account_id).not_to eq nil
      expect(response.payment_account_id).not_to eq ""
    end

    it "enables using the permanent token on other transactions" do
      payment_account_id = response.payment_account_id

      auth_response = Vantiv.auth(
        amount: 10000,
        payment_account_id: payment_account_id,
        customer_id: "doesntmatter",
        order_id: "orderblah"
      )
      expect(auth_response.success?).to eq true
    end

    it "returns a transaction id" do
      expect(response.transaction_id).not_to eq nil
      expect(response.transaction_id).not_to eq ""
    end
  end

  context "with a blank temporary token" do

    it "raises an error" do
      expect{
        Vantiv.tokenize(temporary_token: "")
      }.to raise_error ArgumentError, /blank temporary token/i
    end
  end

  context "with an invalid account number
           (where number is technically valid, and the actual account is invalid)" do

    before :all do
      @card_to_tokenize = Vantiv::TestAccount.invalid_account_number
      @paypage_registration_id = get_paypage_registration_id
    end

    let(:paypage_registration_id) { @paypage_registration_id }

    it "returns success" do
      expect(response.success?).to eq true
      expect(response.failure?).to eq false
    end

    it "returns a permanent token" do
      expect(response.payment_account_id).not_to eq nil
      expect(response.payment_account_id).not_to eq ""
    end

    it "returns a transaction id" do
      expect(response.transaction_id).not_to eq nil
      expect(response.transaction_id).not_to eq ""
    end

    it "notifies that the account is invalid on a subsequent transaction" do
      payment_account_id = response.payment_account_id

      auth_response = Vantiv.auth(
        amount: 10000,
        payment_account_id: payment_account_id,
        customer_id: "doesntmatter",
        order_id: "orderblah"
      )
      expect(auth_response.success?).to eq false
      expect(auth_response.invalid_account_number?).to eq true
    end
  end

  context "with an invalid temporary token" do
    let(:paypage_registration_id) do
      "d8Vp9k5Ja7JidnptLythMnhDb3FjQ3IzZlA1RG1CLzhrd2cwbHladUhuNTBucy94c1R2NDdWN2JoUFNLTng1cQ=="
    end

    it "returns failure" do
      expect(response.success?).to eq false
      expect(response.failure?).to eq true
    end

    it "does not return a permanent token" do
      expect(response.payment_account_id).to eq nil
    end

    it "returns a corresponding response code" do
      expect(response.response_code).to eq(
        Vantiv::Api::TokenizationResponse::ResponseCodes[:invalid_paypage_registration_id]
      )
    end

    it "returns a transaction id" do
      expect(response.transaction_id).not_to eq nil
      expect(response.transaction_id).not_to eq ""
    end
  end

  def get_paypage_registration_id
    visit(@test_paypage_server.root_path)
    expect(page).to have_content("Vantiv Test Paypage")

    within_frame "vantiv-payframe" do
      fill_in("accountNumber", with: @card_to_tokenize.card_number)
      fill_in("cvv", with: @card_to_tokenize.cvv)
    end

    click_button "Submit"

    expect(page).to have_content "Request Complete"
    temp_token = find("#temp-token").text
    expect(temp_token).not_to eq nil
    expect(temp_token).not_to eq ""
    temp_token
  end
end