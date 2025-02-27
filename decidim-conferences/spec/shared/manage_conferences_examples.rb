# frozen_string_literal: true

shared_examples "manage conferences" do
  describe "creating a conference" do
    let(:image1_filename) { "city.jpeg" }
    let(:image1_path) { Decidim::Dev.asset(image1_filename) }

    let(:image2_filename) { "city2.jpeg" }
    let(:image2_path) { Decidim::Dev.asset(image2_filename) }

    before do
      click_link "New conference"
    end

    %w(description short_description objectives).each do |field|
      it_behaves_like "having a rich text editor for field", ".tabs-content[data-tabs-content='conference-#{field}-tabs']", "full"
    end
    it_behaves_like "having a rich text editor for field", "#conference_registrations_terms", "content"

    it "creates a new conference" do
      within ".new_conference" do
        fill_in_i18n(
          :conference_title,
          "#conference-title-tabs",
          en: "My conference",
          es: "Mi proceso participativo",
          ca: "El meu procés participatiu"
        )
        fill_in_i18n(
          :conference_slogan,
          "#conference-slogan-tabs",
          en: "Slogan",
          es: "Eslogan",
          ca: "Eslógan"
        )
        fill_in_i18n_editor(
          :conference_short_description,
          "#conference-short_description-tabs",
          en: "Short description",
          es: "Descripción corta",
          ca: "Descripció curta"
        )
        fill_in_i18n_editor(
          :conference_description,
          "#conference-description-tabs",
          en: "A longer description",
          es: "Descripción más larga",
          ca: "Descripció més llarga"
        )

        fill_in :conference_weight, with: 1
        fill_in :conference_slug, with: "slug"
        fill_in :conference_hashtag, with: "#hashtag"
      end

      dynamically_attach_file(:conference_hero_image, image1_path)
      dynamically_attach_file(:conference_banner_image, image2_path)

      within ".new_conference" do
        fill_in_datepicker :conference_start_date_date, with: 1.month.ago.strftime("%d/%m/%Y")
        fill_in_datepicker :conference_end_date_date, with: (1.month.ago + 3.days).strftime("%d/%m/%Y")

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")

      within "[data-content]" do
        expect(page).to have_current_path decidim_admin_conferences.conferences_path
        expect(page).to have_content("My conference")
      end
    end
  end

  describe "updating a conference" do
    let(:image3_filename) { "city3.jpeg" }
    let(:image3_path) { Decidim::Dev.asset(image3_filename) }

    before do
      within "tr", text: translated(conference.title) do
        click_link "Configure"
      end
    end

    it "updates a conference" do
      fill_in_i18n(
        :conference_title,
        "#conference-title-tabs",
        en: "My new title",
        es: "Mi nuevo título",
        ca: "El meu nou títol"
      )
      dynamically_attach_file(:conference_banner_image, image3_path, remove_before: true)

      within ".edit_conference" do
        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")

      within "[data-content]" do
        expect(page).to have_css("input[value='My new title']")
        expect(page).to have_css("img[src*='#{image3_filename}']")
      end
    end
  end

  describe "updating a conference without images" do
    before do
      within "tr", text: translated(conference.title) do
        click_link "Configure"
      end
    end

    %w(description short_description objectives).each do |field|
      it_behaves_like "having a rich text editor for field", ".tabs-content[data-tabs-content='conference-#{field}-tabs']", "full"
    end
    it_behaves_like "having a rich text editor for field", "#conference_registrations_terms", "content"

    it "update an conference without images does not delete them" do
      within_admin_sidebar_menu do
        click_link "About this conference"
      end
      click_button "Update"

      expect(page).to have_admin_callout("successfully")

      expect(page).to have_css("img[src*='#{conference.attached_uploader(:hero_image).path}']")
      expect(page).to have_css("img[src*='#{conference.attached_uploader(:banner_image).path}']")
    end
  end

  describe "previewing conferences" do
    context "when the conference is unpublished" do
      let!(:conference) { create(:conference, :unpublished, organization:) }

      it "allows the user to preview the unpublished conference" do
        within "tr", text: translated(conference.title) do
          click_link "Preview"
        end

        expect(page).to have_content(translated(conference.title))
      end
    end

    context "when the conference is published" do
      let!(:conference) { create(:conference, organization:) }

      it "allows the user to preview the unpublished conference" do
        new_window = window_opened_by do
          within "tr", text: translated(conference.title) do
            click_link "Preview"
          end
        end

        page.within_window(new_window) do
          expect(page).to have_current_path decidim_conferences.conference_path(conference)
          expect(page).to have_content(translated(conference.title))
        end
      end
    end
  end

  describe "viewing a missing conference" do
    it_behaves_like "a 404 page" do
      let(:target_path) { decidim_admin_conferences.conference_path(99_999_999) }
    end
  end

  describe "publishing a conference" do
    let!(:conference) { create(:conference, :unpublished, organization:) }

    before do
      within "tr", text: translated(conference.title) do
        click_link "Configure"
      end
    end

    it "publishes the conference" do
      click_link "Publish"
      expect(page).to have_content("successfully published")
      expect(page).to have_content("Unpublish")
      expect(page).to have_current_path decidim_admin_conferences.edit_conference_path(conference)

      conference.reload
      expect(conference).to be_published
    end
  end

  describe "unpublishing a conference" do
    let!(:conference) { create(:conference, organization:) }

    before do
      within "tr", text: translated(conference.title) do
        click_link "Configure"
      end
    end

    it "unpublishes the conference" do
      click_link "Unpublish"
      expect(page).to have_content("successfully unpublished")
      expect(page).to have_content("Publish")
      expect(page).to have_current_path decidim_admin_conferences.edit_conference_path(conference)

      conference.reload
      expect(conference).not_to be_published
    end
  end

  context "when there are multiple organizations in the system" do
    let!(:external_conference) { create(:conference) }

    it "does not let the admin manage conferences form other organizations" do
      within "table" do
        expect(page).to have_no_content(external_conference.title["en"])
      end
    end
  end

  context "when the conference has a scope" do
    let(:scope) { create(:scope, organization:) }

    before do
      conference.update!(scopes_enabled: true, scope:)
    end

    it "disables the scope for the conference" do
      within "tr", text: translated(conference.title) do
        click_link "Configure"
      end

      uncheck :conference_scopes_enabled

      expect(page).to have_css("select#conference_scope_id[disabled]")

      within ".edit_conference" do
        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")
    end
  end
end
