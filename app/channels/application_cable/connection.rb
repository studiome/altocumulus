module ApplicationCable
  # The live update socket is only for signed-in users with a live session:
  # the same rule as ApplicationController (see SessionUser).
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      session = request.session
      user = SessionUser.find(session)
      reject_unauthorized_connection if user.nil? || SessionUser.idle?(session)

      self.current_user = user
    end
  end
end
