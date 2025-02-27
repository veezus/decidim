# frozen_string_literal: true

require "spec_helper"

describe "Admin manages assemblies" do
  include_context "when admin administrating an assembly"

  let(:resource_controller) { Decidim::Assemblies::Admin::AssembliesController }
  let(:model_name) { assembly.class.model_name }

  context "when conditionally displaying private user menu entry" do
    let!(:my_space) { create(:assembly, organization:, private_space:) }

    before do
      switch_to_host(organization.host)
      login_as user, scope: :user
      visit decidim_admin_assemblies.assemblies_path
      click_link translated(my_space.title)
    end

    context "when the participatory space is private" do
      let(:private_space) { true }

      it "hides the private user menu entry" do
        within_admin_sidebar_menu do
          expect(page).to have_content("Private users")
        end
      end
    end

    context "when the participatory space is public" do
      let(:private_space) { false }

      it "shows the private user menu entry" do
        within_admin_sidebar_menu do
          expect(page).to have_no_content("Private users")
        end
      end
    end
  end

  shared_examples "creating an assembly" do
    let(:image1_filename) { "city.jpeg" }
    let(:image1_path) { Decidim::Dev.asset(image1_filename) }

    let(:image2_filename) { "city2.jpeg" }
    let(:image2_path) { Decidim::Dev.asset(image2_filename) }

    before do
      click_link "New assembly"
    end

    %w(purpose_of_action composition description short_description announcement internal_organisation).each do |field|
      it_behaves_like "having a rich text editor for field", ".tabs-content[data-tabs-content='assembly-#{field}-tabs']", "full"
    end

    it_behaves_like "having a rich text editor for field", "#closing_date_reason_div", "content"

    it "creates a new assembly" do
      within ".new_assembly" do
        fill_in_i18n(
          :assembly_title,
          "#assembly-title-tabs",
          en: "My assembly",
          es: "Mi proceso participativo",
          ca: "El meu procés participatiu"
        )
        fill_in_i18n(
          :assembly_subtitle,
          "#assembly-subtitle-tabs",
          en: "Subtitle",
          es: "Subtítulo",
          ca: "Subtítol"
        )
        fill_in_i18n_editor(
          :assembly_short_description,
          "#assembly-short_description-tabs",
          en: "Short description",
          es: "Descripción corta",
          ca: "Descripció curta"
        )
        fill_in_i18n_editor(
          :assembly_description,
          "#assembly-description-tabs",
          en: "A longer description",
          es: "Descripción más larga",
          ca: "Descripció més llarga"
        )

        fill_in :assembly_slug, with: "slug"
        fill_in :assembly_hashtag, with: "#hashtag"
        fill_in :assembly_weight, with: 1
      end

      dynamically_attach_file(:assembly_hero_image, image1_path)
      dynamically_attach_file(:assembly_banner_image, image2_path)

      within ".new_assembly" do
        find("*[type=submit]").click
      end

      expect(page).to have_admin_callout("successfully")

      within "[data-content]" do
        expect(page).to have_current_path decidim_admin_assemblies.assemblies_path(q: { parent_id_eq: parent_assembly&.id })
        expect(page).to have_content("My assembly")
      end
    end
  end

  context "when managing parent assemblies" do
    let(:parent_assembly) { nil }
    let!(:assembly) { create(:assembly, :with_content_blocks, organization:, blocks_manifests: [:announcement]) }

    before do
      switch_to_host(organization.host)
      login_as user, scope: :user
      visit decidim_admin_assemblies.assemblies_path
    end

    it_behaves_like "manage assemblies"
    it_behaves_like "creating an assembly"
    it_behaves_like "manage assemblies announcements"

    describe "listing parent assemblies" do
      it_behaves_like "filtering collection by published/unpublished"
      it_behaves_like "filtering collection by private/public"

      context "when filtering by assemblies type" do
        include_context "with filterable context"

        let!(:assemblies_type1) { create(:assemblies_type) }
        let!(:assemblies_type2) { create(:assemblies_type) }

        Decidim::AssembliesType.all.each do |assemblies_type|
          i18n_assemblies_type = assemblies_type.name[I18n.locale.to_s]

          context "when filtering collection by assemblies_type: #{i18n_assemblies_type}" do
            let!(:assembly1) { create(:assembly, organization:, assemblies_type: assemblies_type1) }
            let!(:assembly2) { create(:assembly, organization:, assemblies_type: assemblies_type2) }

            it_behaves_like "a filtered collection", options: "Assembly type", filter: i18n_assemblies_type do
              let(:in_filter) { translated(assembly_with_type(type).title) }
              let(:not_in_filter) { translated(assembly_without_type(type).title) }
            end
          end
        end

        it_behaves_like "paginating a collection"

        def assembly_with_type(type)
          Decidim::Assembly.find_by(decidim_assemblies_type_id: type)
        end

        def assembly_without_type(type)
          Decidim::Assembly.where.not(decidim_assemblies_type_id: type).sample
        end
      end
    end
  end

  context "when managing child assemblies" do
    let!(:parent_assembly) { create(:assembly, organization:) }
    let!(:child_assembly) { create(:assembly, :with_content_blocks, organization:, parent: parent_assembly, blocks_manifests: [:announcement]) }
    let(:assembly) { child_assembly }

    before do
      switch_to_host(organization.host)
      login_as user, scope: :user
      visit decidim_admin_assemblies.assemblies_path
      within "tr", text: translated(parent_assembly.title) do
        click_link "Assemblies"
      end
    end

    it_behaves_like "manage assemblies"
    it_behaves_like "creating an assembly"
    it_behaves_like "manage assemblies announcements"

    describe "listing child assemblies" do
      it_behaves_like "filtering collection by published/unpublished" do
        let!(:published_space) { child_assembly }
        let!(:unpublished_space) { create(:assembly, :unpublished, parent: parent_assembly, organization:) }
      end

      it_behaves_like "filtering collection by private/public" do
        let!(:public_space) { child_assembly }
        let!(:private_space) { create(:assembly, :private, parent: parent_assembly, organization:) }
      end
    end
  end
end
