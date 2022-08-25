# name: discourse-group-expiration
# version: 1.0
# author: richard@communiteq.com
# about: Expire group memberships and send notifications about it
# url: https://www.github.com/communiteq/discourse-group-expiration

enabled_site_setting :group_expiration_enabled

PLUGIN_NAME ||= "discourse-group-expiration".freeze

after_initialize do

  module ::GroupExpiration
    class GroupExpiration::Utils
      def self.send_pm(username, key, nv = {})
        system_user = Discourse.system_user
        title = I18n.t("group_expiration.pm_#{key}_title", nv)
        body = I18n.t("group_expiration.pm_#{key}_body", nv)
        post = PostCreator.create!(
          system_user,
          title: title,
          raw: body,
          archetype: Archetype.private_message,
          target_usernames: username,
          skip_validations: true
        )
        post.topic.update_status('closed', true, system_user)
      end
    end
  end

  require_dependency File.expand_path("../jobs/scheduled/group_expiration_checks.rb", __FILE__)
end
