require "test_helper"

class Api::HousesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_houses_index_url
    assert_response :success
  end
end
