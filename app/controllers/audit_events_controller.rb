require "csv"

class AuditEventsController < ApplicationController
  # Reuses audit_change_rows so the CSV's "Changes" column reads exactly like
  # the show page's before/after table (foreign keys resolved to their
  # record's label, dates/booleans localized) rather than dumping raw JSON.
  include AuditEventsHelper

  # Excel on a Japanese system reads a BOM-less UTF-8 CSV as Shift_JIS and
  # renders mojibake, so the export leads with a BOM.
  UTF8_BOM = "﻿".freeze

  def index
    scope = AuditEvent.filtered(**filter_params).recent_first.includes(:user)

    respond_to do |format|
      format.html do
        @pagination = Pagination.new(scope, page: params[:page])
        @audit_events = @pagination.records
        @operators = User.order(:name)
      end
      # The CSV deliberately ignores the page param and exports every row the
      # current filters match: the point of the export is to take the log out
      # of the app, which one page of 25 cannot do.
      format.csv do
        send_data audit_events_csv(scope),
                  type: "text/csv; charset=utf-8",
                  filename: "audit_log_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
      end
    end
  end

  def show
    @audit_event = AuditEvent.find(params.expect(:id))
  end

  private

    # The filter field cannot be named "action": params[:action] is always the
    # routing action ("index"), and leaking it into query_parameters makes the
    # pagination links generate a URL for a non-existent audit_events#create.
    def filter_params
      permitted = params.permit(:auditable_type, :audit_action, :user_id)
      { auditable_type: permitted[:auditable_type], action: permitted[:audit_action], user_id: permitted[:user_id] }
    end

    def audit_events_csv(scope)
      CSV.generate(+UTF8_BOM) do |csv|
        csv << [
          t("audit_events.labels.time"),
          t("audit_events.labels.record_type"),
          t("audit_events.labels.record_id"),
          AuditEvent.human_attribute_name(:action),
          t("audit_events.index.record_header"),
          t("audit_events.labels.operator"),
          t("audit_events.labels.ip_address"),
          t("audit_events.index.changes_header")
        ]

        # find_each batches rather than loading an unbounded log into memory.
        # It orders by primary key, so `order: :desc` (not the scope's
        # recent_first) is what keeps the export newest-first -- the two agree
        # here because audit rows are only ever appended.
        scope.find_each(order: :desc) do |audit_event|
          csv << [
            l(audit_event.created_at, format: :timestamp),
            audit_event.auditable_type_label,
            audit_event.auditable_id,
            audit_event.action_label,
            audit_event.record_label,
            audit_event.user&.name || t("common.none"),
            audit_event.ip_address || t("common.none"),
            audit_change_summary(audit_event)
          ]
        end
      end
    end

    def audit_change_summary(audit_event)
      audit_change_rows(audit_event)
        .map { |row| "#{row[:label]}: #{row[:before]} -> #{row[:after]}" }
        .join("\n")
    end
end
