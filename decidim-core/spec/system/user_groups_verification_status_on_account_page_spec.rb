# frozen_string_literal: true

require "spec_helper"

describe "User group verification status on account page" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }

  before do
    switch_to_host(organization.host)
    create(:user_group_membership, user:, user_group:)
    login_as user, scope: :user
  end

  context "when the user group is pending" do
    let(:user_group) { create(:user_group) }

    it "the user can check their status on their account page" do
      visit decidim.own_user_groups_path

      within "#dropdown-menu-profile" do
        click_link "Groups"
      end

      expect(page).to have_content(user_group.name)
      expect(page).to have_no_css("div.profile__user-avatar-badge")
    end

    describe "#verified?" do
      it "returns false" do
        expect(user_group.verified?).to be(false)
      end
    end
  end

  context "when the user group is rejected" do
    let(:user_group) { create(:user_group, :rejected) }

    it "the user can check their status on their account page" do
      visit decidim.own_user_groups_path

      within "#dropdown-menu-profile" do
        click_link "Groups"
      end

      expect(page).to have_content(user_group.name)
      expect(page).to have_no_css("div.profile__user-avatar-badge")
    end
  end

  context "when the user group is verified" do
    let(:user_group) { create(:user_group, :verified) }

    it "the user can check their status on their account page" do
      visit decidim.own_user_groups_path

      within "#dropdown-menu-profile" do
        click_link "Groups"
      end

      expect(page).to have_content(user_group.name)
      expect(page).to have_css("div.profile__user-avatar-badge")
    end

    describe "#verified?" do
      it "returns true" do
        expect(user_group.verified?).to be(true)
      end
    end
  end
end
