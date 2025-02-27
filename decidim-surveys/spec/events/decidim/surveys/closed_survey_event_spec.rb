# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Surveys
    describe ClosedSurveyEvent do
      include Decidim::ComponentPathHelper

      include_context "when a simple event"

      let(:event_name) { "decidim.events.surveys.survey_closed" }
      let(:resource) { create(:surveys_component) }
      let(:participatory_space) { resource.participatory_space }
      let(:resource_path) { main_component_path(resource) }
      let(:email_subject) { "A survey has finished in #{decidim_sanitize_translated(participatory_space.title)}" }
      let(:email_intro) { "The survey #{resource.name["en"]} in #{participatory_space_title} has been closed." }
      let(:email_outro) { "You have received this notification because you are following #{participatory_space_title}. You can stop receiving notifications following the previous link." }
      let(:notification_title) { "The survey <a href=\"#{resource_path}\">#{resource.name["en"]}</a> in <a href=\"#{participatory_space_url}\">#{participatory_space_title}</a> has finished." }

      it_behaves_like "a simple event"
      it_behaves_like "a simple event email"
      it_behaves_like "a simple event notification"
    end
  end
end
