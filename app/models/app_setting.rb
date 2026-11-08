# App-wide settings an administrator can change at runtime, kept in a single
# row (SINGLETON_ID) rather than one row per key: there is one settings
# screen and everything on it applies to the whole installation.
#
# The application title has three levels: what an admin saved here wins,
# otherwise the APP_TITLE environment variable read at boot
# (config.x.app_title), otherwise the built-in name. That way a fresh deploy
# can be branded with an env var alone, before anyone signs in. The theme is
# one of AppTheme::KEYS, nil meaning the default.
class AppSetting < ApplicationRecord
  SINGLETON_ID = 1
  MAX_TITLE_LENGTH = 60

  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :theme, inclusion: { in: AppTheme::KEYS }, allow_blank: true

  def self.current
    find_by(id: SINGLETON_ID) || new(id: SINGLETON_ID)
  end

  def self.title
    current.title.presence || default_title
  end

  # The colour palette (see AppTheme) applied to every user; blank means the
  # default.
  def self.theme
    current.theme.presence || AppTheme::DEFAULT
  end

  def self.default_title
    Rails.application.config.x.app_title
  end
end
