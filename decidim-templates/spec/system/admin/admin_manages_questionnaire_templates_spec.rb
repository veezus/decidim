# frozen_string_literal: true

require "spec_helper"

describe "Admin manages questionnaire templates" do
  let!(:organization) { create(:organization) }
  let!(:user) { create(:user, :admin, :confirmed, organization:) }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
    visit decidim_admin_templates.questionnaire_templates_path
  end

  it_behaves_like "needs admin TOS accepted" do
    let(:user) { create(:user, :admin, :confirmed, admin_terms_accepted_at: nil, organization:) }
  end

  describe "listing templates" do
    let!(:template) { create(:questionnaire_template, organization:) }

    before do
      visit decidim_admin_templates.questionnaire_templates_path
    end

    it "shows a table with the templates info" do
      within ".questionnaire-templates" do
        expect(page).to have_i18n_content(template.name)
        expect(page).to have_i18n_content(template.templatable.title)
      end
    end
  end

  describe "creating a questionnaire_template" do
    before do
      within ".layout-content" do
        click_link("New")
      end
    end

    it "creates a new template with a questionnaire as templatable" do
      within ".new_questionnaire_template" do
        fill_in_i18n(
          :template_name,
          "#template-name-tabs",
          en: "My template",
          es: "Mi plantilla",
          ca: "La meva plantilla"
        )
        fill_in_i18n(
          :template_description,
          "#template-description-tabs",
          en: "Description",
          es: "Descripción",
          ca: "Descripció"
        )

        click_button "Save", match: :first
      end

      expect(page).to have_admin_callout("successfully")

      within "[data-content]" do
        expect(page).to have_current_path decidim_admin_templates.edit_questionnaire_template_path(Decidim::Templates::Template.last.id)
        expect(page.find_by_id("template_name_en").value).to eq("My template")

        click_link "Edit"
      end

      within ".card-section" do
        fill_in_i18n(
          :questionnaire_title,
          "#questionnaire-title-tabs",
          en: "My questionnaire",
          es: "Mi encuesta",
          ca: "La meva enquesta"
        )

        fill_in_i18n_editor(
          :questionnaire_tos,
          "#questionnaire-tos-tabs",
          en: "My terms",
          es: "Mis términos",
          ca: "Els meus termes"
        )
      end

      click_button "Save"
      expect(page).to have_admin_callout("successfully")
    end
  end

  describe "trying to create a questionnaire_template with invalid data" do
    before do
      within ".layout-content" do
        click_link("New")
      end
    end

    it "fails to create a new questionnaire_template" do
      within ".new_questionnaire_template" do
        fill_in_i18n(
          :template_name,
          "#template-name-tabs",
          en: "",
          es: "",
          ca: ""
        )
        fill_in_i18n(
          :template_description,
          "#template-description-tabs",
          en: "Description",
          es: "Descripción",
          ca: "Descripció"
        )

        find("*[type=submit]", match: :first).click
      end

      expect(page).to have_admin_callout("problem")
    end
  end

  describe "updating a template" do
    let!(:template) { create(:questionnaire_template, organization:) }

    before do
      visit decidim_admin_templates.questionnaire_templates_path
      click_link translated(template.name)
    end

    it "updates a template" do
      fill_in_i18n(
        :template_name,
        "#template-name-tabs",
        en: "My new name",
        es: "Mi nuevo nombre",
        ca: "El meu nou nom"
      )

      within ".edit_questionnaire_template" do
        page.find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")

      within "[data-content]" do
        expect(page).to have_current_path decidim_admin_templates.edit_questionnaire_template_path(template)
        expect(page.find_by_id("template_name_en").value).to eq("My new name")
      end
    end
  end

  describe "updating a template with invalid values" do
    let!(:template) { create(:questionnaire_template, organization:) }

    before do
      visit decidim_admin_templates.questionnaire_templates_path
      click_link translated(template.name)
    end

    it "does not update the template" do
      fill_in_i18n(
        :template_name,
        "#template-name-tabs",
        en: "",
        es: "",
        ca: ""
      )

      within ".edit_questionnaire_template" do
        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("problem")
    end
  end

  describe "copying a template" do
    let!(:template) { create(:questionnaire_template, organization:) }

    before do
      visit decidim_admin_templates.questionnaire_templates_path
    end

    it "copies the template" do
      within "tr", text: translated(template.name) do
        click_link "Duplicate"
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_content(template.name["en"], count: 2)
    end
  end

  describe "editing the questionnaire_template's questionnaire" do
    let!(:template) { create(:questionnaire_template, organization:) }

    before do
      visit decidim_admin_templates.questionnaire_templates_path
    end

    it "shows a functional questionnaire form" do
      within ".layout-content" do
        click_link("Edit")
      end

      within "[data-content]" do
        click_link("Edit")
      end

      within ".edit_questionnaire" do
        fill_in_i18n(
          :questionnaire_title,
          "#questionnaire-title-tabs",
          en: "My questionnaire",
          es: "Mi formulario",
          ca: "El meu formulari"
        )

        fill_in_i18n_editor(
          :questionnaire_tos,
          "#questionnaire-tos-tabs",
          en: "My terms",
          es: "Mis términos",
          ca: "Els meus termes"
        )

        click_button "Add question"
        find(".button.expand-all").click

        within ".questionnaire-question" do
          find("[id$=body_en]").fill_in(with: "My question")
        end

        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")

      within "[data-content]" do
        expect(page).to have_current_path decidim_admin_templates.edit_questionnaire_template_path(template)
        expect(page).to have_content("My question")
      end
    end

    it "does not show preview or answers buttons" do
      within ".layout-content" do
        click_link("Edit")
      end

      within "[data-content]" do
        click_link("Edit")
      end

      within ".item_show__header" do
        expect(page).to have_no_button("Preview")
        expect(page).to have_no_button("No answers yet")
      end
    end
  end

  describe "destroying a template" do
    let!(:template) { create(:questionnaire_template, organization:) }

    before do
      visit decidim_admin_templates.questionnaire_templates_path
    end

    it "destroys the template" do
      within "tr", text: translated(template.name) do
        accept_confirm { click_link "Delete" }
      end

      expect(page).to have_admin_callout("successfully")
      expect(page).to have_no_i18n_content(template.name)
    end
  end

  describe "previewing a questionnaire_template" do
    let!(:template) { create(:questionnaire_template, organization:) }
    let!(:questions) { create_list(:questionnaire_question, 3, questionnaire: template.templatable) }
    let(:questionnaire) { template.templatable }

    before do
      visit decidim_admin_templates.edit_questionnaire_template_path(template)
    end

    it "shows the template preview" do
      within ".questionnaire-template-preview" do
        expect(page).to have_i18n_content(questionnaire.title)
        expect(page).to have_i18n_content(questionnaire.questions.first.body)
        expect(page).to have_field(id: "questionnaire_responses_0")
        expect(page).to have_css("button[type=submit][disabled]")
      end
    end
  end
end
