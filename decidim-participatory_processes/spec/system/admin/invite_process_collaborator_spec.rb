# frozen_string_literal: true

require "spec_helper"

describe "Invite process collaborator" do
  include_context "when inviting process users"
  let(:role) { "Collaborator" }

  before do
    switch_to_host organization.host
  end

  context "when the user does not exist" do
    before do
      perform_enqueued_jobs { invite_user }
    end

    it "asks for a password and nickname and redirects to the admin dashboard" do
      visit last_email_link

      within "form.new_user" do
        fill_in :invitation_user_nickname, with: "caballo_loco"
        fill_in :invitation_user_password, with: "decidim123456789"
        check :invitation_user_tos_agreement
        find("*[type=submit]").click
      end

      expect(page).to have_current_path "/admin/admin_terms/show"

      visit decidim_admin.admin_terms_show_path
      find_button("I agree with the terms").click

      click_link "Processes"

      within "div.table-scroll" do
        expect(page).to have_i18n_content(participatory_process.title)
      end
    end
  end

  context "when the user already exists" do
    let(:email) { "collaborator@example.org" }

    let!(:collaborator) do
      create(:user, :confirmed, :admin_terms_accepted, email:, organization:)
    end

    before do
      perform_enqueued_jobs { invite_user }
    end

    it "redirects the collaborator to the admin dashboard" do
      login_as collaborator, scope: :user

      visit decidim_admin.root_path

      click_link "Processes"

      within "div.table-scroll" do
        expect(page).to have_i18n_content(participatory_process.title)
      end
    end
  end
end
