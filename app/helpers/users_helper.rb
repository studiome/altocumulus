module UsersHelper
  # Renders the login-id input with the field type appropriate for the
  # server's configured account_identifier mode: an <input type="email">
  # when logging in by email address, or a plain text field when logging in
  # by username. Used by every form that edits :login_id (session/new,
  # accounts/show, admin/users/_form) so they all follow the same mode
  # without duplicating the branch.
  def login_id_field(form, **html_options)
    if User.identifier_email?
      form.email_field(:login_id, **html_options)
    else
      form.text_field(:login_id, **html_options)
    end
  end
end
