module ApplicationHelper
  # The installation's own name (see AppSetting). Memoized because the layout
  # asks for it more than once per request.
  def app_title
    @app_title ||= AppSetting.title
  end
end
