module Admin
  class AdminNotesController < ApplicationController
    before_action :require_admin

    def index
      @admin_notes = AdminNote.recent_first.includes(:user)
      @admin_note = AdminNote.new
    end

    def create
      @admin_note = AdminNote.new(admin_note_params)
      @admin_note.user = current_user

      if @admin_note.save
        redirect_to admin_admin_notes_path, notice: "Note was successfully added."
      else
        @admin_notes = AdminNote.recent_first.includes(:user)
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      AdminNote.find(params.expect(:id)).destroy
      redirect_to admin_admin_notes_path, notice: "Note was successfully deleted.", status: :see_other
    end

    private

    def admin_note_params
      params.expect(admin_note: [ :body ])
    end
  end
end
