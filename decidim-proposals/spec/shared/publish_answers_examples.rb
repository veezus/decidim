# frozen_string_literal: true

shared_examples "publish answers" do
  context "when publishing answers at once" do
    before do
      create_list(:proposal, 3, :accepted_not_published, component: current_component)

      visit current_path
    end

    it "publishes some answers" do
      page.find_by_id("proposals_bulk", class: "js-check-all").set(true)
      page.first("[data-published-state=false] .js-proposal-list-check").set(false)

      click_button "Actions"
      click_button "Publish answers"

      within "#js-publish-answers-actions" do
        expect(page).to have_content("Answers for 2 proposal's will be published?")
      end

      click_button(id: "js-submit-publish-answers")
      20.times do # wait for the ajax call to finish
        sleep(1)
        expect(page).to have_content(I18n.t("proposals.publish_answers.success", scope: "decidim"))
        break
      rescue StandardError
        # ignore and loop again if ajax content is still not there
        nil
      end
      expect(page).to have_content(I18n.t("proposals.publish_answers.success", scope: "decidim"))

      visit current_path

      expect(page).to have_content("Accepted", count: 3)
    end

    it "cannot publish answers for non answered proposals" do
      page.find_by_id("proposals_bulk", class: "js-check-all").set(true)
      page.all("[data-published-state=false] .js-proposal-list-check").each { |c| c.set(false) }

      click_button "Actions"
      expect(page).to have_no_content("Publish answers")
    end
  end
end
