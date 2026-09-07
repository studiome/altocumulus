module Admin
  class AnnouncementsController < ApplicationController
    before_action :require_admin
    before_action :set_announcement, only: %i[ edit update destroy ]

    def index
      @announcements = Announcement.recent_first
    end

    def new
      @announcement = Announcement.new(published: true)
    end

    def create
      @announcement = Announcement.new(announcement_params)

      if @announcement.save
        redirect_to admin_announcements_path, notice: t(".success_notice")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @announcement.update(announcement_params)
        redirect_to admin_announcements_path, notice: t(".success_notice"), status: :see_other
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @announcement.destroy
      redirect_to admin_announcements_path, notice: t(".success_notice"), status: :see_other
    end

    private

    def set_announcement
      @announcement = Announcement.find(params.expect(:id))
    end

    def announcement_params
      params.expect(announcement: [ :title, :body, :published ])
    end
  end
end
