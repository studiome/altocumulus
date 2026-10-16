# The terms of one team and the members of each term. Any signed-in user may
# edit them, like the masters (a clerk enters the members the chief decides).
class TeamTermsController < ApplicationController
  include RequiresTeamsFeature

  before_action :set_team
  before_action :set_term, only: %i[ edit update destroy ]

  def index
    @terms = @team.team_terms.includes(:team_term_members).reverse_order
  end

  def new
    @term = @team.team_terms.build
  end

  def edit
  end

  def create
    @term = @team.team_terms.build(term_params)

    if @term.save
      redirect_to team_team_terms_path(@team), notice: t(".success_notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @term.update(term_params)
      redirect_to team_team_terms_path(@team), notice: t(".success_notice"), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @term.destroy
    redirect_to team_team_terms_path(@team), notice: t(".success_notice"), status: :see_other
  end

  # Starts the next rotation from the latest term (see TeamTerm#build_successor)
  # and opens it for editing, so the clerk only adjusts what changed.
  def copy_previous
    latest = @team.team_terms.reorder(:ends_on).last
    return redirect_to team_team_terms_path(@team), alert: t(".no_previous_term") if latest.nil?

    copy = latest.build_successor
    if copy.save
      redirect_to edit_team_team_term_path(@team, copy), notice: t(".success_notice")
    else
      redirect_to team_team_terms_path(@team), alert: copy.errors.full_messages.to_sentence
    end
  end

  private

    def set_team
      @team = Team.find(params.expect(:team_id))
    end

    def set_term
      @term = @team.team_terms.find(params.expect(:id))
    end

    def term_params
      params.expect(team_term: [
        :starts_on, :ends_on, :note,
        { team_term_members_attributes: [ [ :id, :user_id, :name, :role, :position, :_destroy ] ] }
      ])
    end
end
