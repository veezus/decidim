# frozen_string_literal: true

shared_examples "manage media links examples" do
  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
    visit decidim_admin_conferences.edit_conference_path(conference)
    within_admin_sidebar_menu do
      click_link "Media Links"
    end
  end

  describe "creating media link" do
    before do
      click_link "New media link"
    end

    it "creates a new media link" do
      within "[data-content]" do
        within ".new_media_link" do
          fill_in_i18n(
            :conference_media_link_title,
            "#conference_media_link-title-tabs",
            en: "Media Link en",
            es: "Media Link es",
            ca: "Media Link ca"
          )

          fill_in :conference_media_link_link, with: "https://decidim.org"
          fill_in :conference_media_link_weight, with: 2
          fill_in_datepicker :conference_media_link_date_date, with: "24/10/2018"
        end

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")

      within "[data-content]" do
        expect(page).to have_current_path decidim_admin_conferences.conference_media_links_path(conference)
        expect(page).to have_content("Media Link en")
      end
    end
  end

  describe "when managing other conference media links" do
    let!(:media_link) { create(:media_link, conference:) }

    before do
      visit current_path
    end

    it "shows conference media links list" do
      within "#media_links table" do
        expect(page).to have_content(translated(media_link.title))
      end
    end

    it "updates a conference media links" do
      within "#media_links tr", text: translated(media_link.title) do
        click_link "Edit"
      end

      within ".edit_media_link" do
        fill_in_i18n(
          :conference_media_link_title,
          "#conference_media_link-title-tabs",
          en: "Media Link update en",
          es: "Media Link update es",
          ca: "Media Link update ca"
        )

        fill_in :conference_media_link_link, with: "https://decidim.org"
        fill_in :conference_media_link_weight, with: 2
        fill_in_datepicker :conference_media_link_date_date, with: 1.month.ago.strftime("%d/%m/%Y")

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_current_path decidim_admin_conferences.conference_media_links_path(conference)

      within "#media_links table" do
        expect(page).to have_content("Media Link update en")
      end
    end

    it "deletes the conference media link" do
      within "#media_links tr", text: translated(media_link.title) do
        accept_confirm { find("a.action-icon--remove").click }
      end

      expect(page).to have_admin_callout("successfully")

      within "#media_links table" do
        expect(page).to have_no_content(translated(media_link.title))
      end
    end
  end

  context "when paginating" do
    let!(:collection_size) { 15 }
    let!(:collection) { create_list(:media_link, collection_size, conference:) }
    let!(:resource_selector) { "#media_links tbody tr" }

    before do
      visit current_path
    end

    it "lists 10 media links per page by default" do
      expect(page).to have_css(resource_selector, count: 10)
      expect(page).to have_css("[data-pages] [data-page]", count: 2)
      click_link "Next"
      expect(page).to have_css("[data-pages] [data-page][aria-current='page']", text: "2")
      expect(page).to have_css(resource_selector, count: 5)
    end
  end
end
