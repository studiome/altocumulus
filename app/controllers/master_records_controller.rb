# Generic CRUD for the admin-editable masters (see MasterRecord). A subclass
# only names its model: DepartmentsController, SurgeryLocationsController and
# SurgicalDevicesController find these shared views in app/views/master_records
# through Rails' controller-inheritance view lookup. Like the other masters
# (diagnoses, holidays...), any signed-in user may edit them.
class MasterRecordsController < ApplicationController
  before_action :set_record, only: %i[ edit update destroy ]
  helper_method :master_class, :collection_path

  def index
    @records = master_class.ordered
  end

  def new
    @record = master_class.new
  end

  def edit
  end

  def create
    @record = master_class.new(record_params)

    if @record.save
      redirect_to collection_path, notice: t("master_records.create.success_notice", record: record_label)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @record.update(record_params)
      redirect_to collection_path, notice: t("master_records.update.success_notice", record: record_label), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @record.destroy
      redirect_to collection_path, notice: t("master_records.destroy.success_notice", record: record_label), status: :see_other
    else
      redirect_to collection_path, alert: @record.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

    def master_class
      raise NotImplementedError, "#{self.class} must define master_class"
    end

    def collection_path
      polymorphic_path(master_class)
    end

    def record_label
      master_class.model_name.human
    end

    def set_record
      @record = master_class.find(params.expect(:id))
    end

    def record_params
      params.expect(master_class.model_name.param_key => [ :name, :position, :active ])
    end
end
