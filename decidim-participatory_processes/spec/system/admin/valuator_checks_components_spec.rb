# frozen_string_literal: true

require "spec_helper"

describe "Valuator checks components" do
  let(:manifest_name) { "proposals" }
  let!(:assigned_proposal) { create(:proposal, component: current_component) }
  let(:participatory_process) { create(:participatory_process, :with_steps, organization:) }
  let(:participatory_space_path) do
    decidim_admin_participatory_processes.edit_participatory_process_path(participatory_process)
  end
  let!(:user) { create(:user, organization:) }
  let!(:valuator_role) { create(:participatory_process_user_role, role: :valuator, user:, participatory_process:) }
  let(:another_component) { create(:component, participatory_space: participatory_process) }

  include Decidim::ComponentPathHelper

  include_context "when managing a component as an admin"

  before do
    user.update(admin: false)

    create(:valuation_assignment, proposal: assigned_proposal, valuator_role:)

    visit current_path
  end

  context "when listing components in the space components page" do
    it "can only see the proposals component" do
      within ".process-title-content" do
        click_link "Components"
      end

      within ".table-list" do
        expect(page).to have_content(translated(current_component.name))
        expect(page).to have_no_content(translated(another_component.name))
      end
    end
  end
end
