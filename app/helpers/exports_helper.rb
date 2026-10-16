module ExportsHelper
  # The configured exports that fit the screen `view` (see ExportSource), for
  # a signed-in admin / data manager; empty for anyone else.
  def exports_for_view(view)
    return [] unless data_exporter?

    subject = ExportSource::SUBJECTS[view.to_s]
    SiteConfig.current.export_definitions.select { |definition| definition.subject == subject }
  end
end
