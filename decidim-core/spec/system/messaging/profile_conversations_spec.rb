# frozen_string_literal: true

require "spec_helper"

describe "ProfileConversations" do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, :confirmed, organization:) }
  let(:another_user) { create(:user, :confirmed, organization:) }
  let(:extra_user) { create(:user, :confirmed, organization:) }
  let(:user_group) { create(:user_group, :confirmed, organization:, users: [user, extra_user]) }

  let(:profile) { user_group }

  before do
    switch_to_host(organization.host)
    login_as user, scope: :user
  end

  context "when visiting profile page" do
    before do
      login_as another_user, scope: :user
      visit decidim.profile_path(nickname: profile.nickname)
    end

    it "has a contact link" do
      expect(page).to have_link(title: "Message", href: decidim.new_conversation_path(recipient_id: profile.id))
    end
  end

  context "when visiting blocked profile page" do
    let(:profile) { create(:user_group, :confirmed, :blocked, organization:, users: [user, extra_user]) }
    let!(:admin) { create(:user, :admin, :confirmed, organization:) }

    before do
      login_as admin, scope: :user
      visit decidim.profile_path(nickname: profile.nickname)
    end

    it "does not have a contact link" do
      expect(page).to have_no_link(title: "Contact", href: decidim.new_conversation_path(recipient_id: profile.id))
    end
  end

  context "when profile has no conversations" do
    before { visit_profile_inbox }

    it "shows a notice informing about that" do
      expect(page).to have_content("There are no conversations yet")
    end
  end

  shared_examples "create new conversation" do
    it "allows sending an initial message", :slow do
      start_conversation("Is this a Ryanair style democracy?")
      expect(page).to have_selector(".conversation__item-snippet-message", text: "Is this a Ryanair style democracy?")
    end

    it "redirects to an existing conversation if it exists already", :slow do
      start_conversation("Is this a Ryanair style democracy?")

      visit decidim.new_profile_conversation_path(nickname: profile.nickname, recipient_id: recipient.id)
      expect(page).to have_selector("#messages .conversation__message:last-child", text: "Is this a Ryanair style democracy?")
    end
  end

  context "when starting a conversation" do
    let(:recipient) { create(:user, organization:) }

    before do
      visit decidim.new_profile_conversation_path(nickname: profile.nickname, recipient_id: recipient.id)
    end

    it "shows an empty conversation page" do
      expect(page).to have_no_selector(".conversation__item")
      expect(page).to have_current_path decidim.new_profile_conversation_path(nickname: profile.nickname, recipient_id: recipient.id)
    end

    it_behaves_like "create new conversation"

    context "and recipient has restricted communications" do
      let(:recipient) { create(:user, direct_message_types: "followed-only", organization:) }

      context "and recipient does not follow user" do
        it "redirects user with access error" do
          expect(page).to have_no_current_path decidim.new_profile_conversation_path(nickname: profile.nickname, recipient_id: recipient.id)
          expect(page).to have_content("You are not authorized to perform this action")
        end

        context "and a conversation exists already" do
          let!(:conversation) do
            Decidim::Messaging::Conversation.start!(
              originator: profile,
              interlocutors: [recipient],
              body: "Is this a Ryanair style democracy?"
            )
          end

          it "shows the existing conversation" do
            visit decidim.profile_conversation_path(nickname: profile.nickname, id: conversation.id)
            expect(page).to have_selector("#messages .conversation__message:last-child", text: "Is this a Ryanair style democracy?")
          end
        end
      end

      context "and recipient follows user" do
        let!(:follow) { create(:follow, user: recipient, followable: profile) }

        before do
          visit decidim.new_profile_conversation_path(nickname: profile.nickname, recipient_id: recipient.id)
        end

        it_behaves_like "create new conversation"
      end
    end
  end

  context "when profile has conversations" do
    let(:interlocutor) { create(:user, :confirmed, organization:) }
    let(:start_message) { "who wants apples?" }
    let!(:conversation) do
      Decidim::Messaging::Conversation.start!(
        originator: profile,
        interlocutors: [interlocutor],
        body: start_message
      )
    end

    context "when visiting profile inbox" do
      before do
        visit_profile_inbox
      end

      it "shows profile's conversation list" do
        expect(page).to have_selector(".conversation__item", text: /#{interlocutor.name}/i)
        expect(page).to have_selector(".conversation__item", text: "who wants apples?")
        expect(page).to have_selector(".conversation__item", text: "less than a minute")
      end

      it "allows entering a conversation" do
        visit_profile_inbox
        click_link "conversation-#{conversation.id}"

        expect(page).to have_content("Conversation with\n#{interlocutor.name}")
        expect(page).to have_content("who wants apples?")
      end

      context "when viewing conversation" do
        before do
          find("#conversation-#{conversation.id}").click
        end

        it_behaves_like "conversation field with maximum length", "message_body"

        describe "reply to conversation" do
          let(:reply_message) { Faker::Lorem.sentence }

          it "can reply to conversation" do
            fill_in "message_body", with: reply_message
            click_button "Send"
            expect(page).to have_content(start_message)
            expect(page).to have_content(reply_message)
          end
        end
      end
    end

    context "and some of them are unread" do
      before do
        conversation.add_message!(sender: interlocutor, body: "I want one")

        visit_profile_inbox
      end

      it "shows the topbar button as active" do
        expect(page).to have_selector("li.profile__tab.is-active a", text: "Conversations")
      end

      it "shows the topbar button the number of unread messages" do
        expect(page).to have_selector("li.profile__tab.is-active .conversation__item-unread", text: "2")
      end

      it "shows the number of unread messages per conversation" do
        expect(page).to have_selector(".conversation__item .conversation__item-unread", text: "2")
      end
    end

    context "and there are several conversations" do
      let!(:conversation2) do
        Decidim::Messaging::Conversation.start!(
          originator: profile,
          interlocutors: [extra_user],
          body: "who wants apples?"
        )
      end

      before do
        conversation.add_message!(sender: interlocutor, body: "I want one")

        visit_profile_inbox
      end

      it "shows the topbar button the number of unread messages" do
        expect(page).to have_selector("li.profile__tab.is-active .conversation__item-unread", text: "3")
      end
    end

    context "and they are read" do
      before do
        visit decidim.profile_conversation_path(nickname: profile.nickname, id: conversation.id)
        visit_profile_inbox
      end

      it "does not show the topbar button the number of unread messages" do
        expect(page).to have_no_selector("li.profile__tab.is-active .conversation__item-unread")
      end

      it "does not show an unread count" do
        expect(page).to have_selector(".conversation__item .conversation__item-unread")
        expect(page.find(".conversation__item .conversation__item-unread").text).to be_blank
      end

      it "conversation page does not show the number of unread messages" do
        visit_inbox

        expect(page).to have_no_selector(".user-groups .card--list__author .card--list__counter")
      end
    end

    context "when a message is sent" do
      before do
        visit_profile_inbox
        click_link "conversation-#{conversation.id}"
        expect(page).to have_content("Send")
        fill_in "message_body", with: "Please reply!"
        click_button "Send"
      end

      it "appears as the last message", :slow do
        click_button "Send"
        expect(page).to have_selector("#messages .conversation__message:last-child", text: "Please reply!")
      end

      context "and interlocutor sees it" do
        before do
          click_button "Send"
          expect(page).to have_selector("#messages .conversation__message:last-child", text: "Please reply!")
          relogin_as interlocutor, scope: :user
          visit decidim.conversations_path
        end

        it "appears as unread", :slow do
          expect(page).to have_selector(".conversation__item-unread", text: "2")
        end

        it "appears as read after it is seen", :slow do
          click_link "conversation-#{conversation.id}"
          expect(page).to have_content("Please reply!")

          visit decidim.conversations_path
          expect(page).to have_selector(".conversation__item .conversation__item-unread")
          expect(page.find(".conversation__item .conversation__item-unread").text).to be_blank
        end
      end
    end

    context "when interlocutor has restricted conversations" do
      let(:interlocutor) { create(:user, :confirmed, direct_message_types: "followed-only", organization:) }

      context "and interlocutor does not follow profile" do
        before do
          visit_profile_inbox
          click_link "conversation-#{conversation.id}"
        end

        it "allows profile to see old messages" do
          expect(page).to have_content("Conversation with\n#{interlocutor.name}")
          expect(page).to have_content("who wants apples?")
        end

        it "does not show the sending form" do
          expect(page).to have_no_selector("textarea#message_body")
        end
      end

      context "and interlocutor follows profile" do
        let!(:follow) { create(:follow, user: interlocutor, followable: profile) }

        before do
          visit_profile_inbox
          click_link "conversation-#{conversation.id}"
          expect(page).to have_content("Send")
          fill_in "message_body", with: "Please reply!"
          click_button "Send"
        end

        it "appears as the last message", :slow do
          click_button "Send"
          expect(page).to have_selector(".conversation__message:last-child", text: "Please reply!")
        end
      end
    end

    describe "on mentioned list" do
      context "when someone direct messages disabled" do
        let!(:interlocutor2) { create(:user, :confirmed, organization:, direct_message_types: "followed-only") }

        it "cannot be selected on the mentioned list", :slow do
          visit_profile_inbox
          expect(page).to have_content("New conversation")
          click_button "New conversation"
          find_by_id("add_conversation_users").fill_in with: "@#{interlocutor2.nickname}"
          expect(page).to have_selector("#autoComplete_list_1 li.disabled", wait: 2)
        end
      end

      context "when starting a new conversation" do
        before do
          visit_profile_inbox
          click_button "New conversation"
        end

        it "has disabled submit button" do
          expect(page).to have_button("Next", disabled: true)
        end

        it "enables submit button after selecting interlocutor" do
          find_by_id("add_conversation_users").fill_in with: "@#{interlocutor.nickname}"
          find_by_id("autoComplete_result_0").click
          expect(page).to have_button("Next", disabled: false)
        end
      end
    end
  end

  private

  def start_conversation(message)
    fill_in "conversation_body", with: message
    click_button "Send"
  end

  def visit_profile_inbox
    visit decidim.profile_path(nickname: profile.nickname)

    click_link "Conversations", class: "profile__tab-item"
  end

  def visit_inbox
    visit decidim.root_path

    find_by_id("trigger-dropdown-account").click
    within "#dropdown-menu-account" do
      click_link("Conversations")
    end
  end
end
