require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get map" do
    get pages_map_url
    assert_response :success
  end
end
