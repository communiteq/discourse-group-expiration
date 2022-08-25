# frozen_string_literal: true

module Jobs
  class GroupExpirationChecks < ::Jobs::Scheduled
    every 2.hours

    def execute(args)
      return unless SiteSetting.group_expiration_enabled

      now = Time.now
      today = now.strftime('%Y-%m-%d')
      now7 = now + 7.days
      nextweek = now7.strftime('%Y-%m-%d')

      UserCustomField.where("name like 'group_expiration_%'").each do |ucf|
        obj = JSON.parse(ucf['value'])
        status = obj['status'] || 'active'
        if (obj['expires'] < nextweek) && (status == 'active')
          # send notification for expiring
          ::GroupExpiration::Utils::send_pm(
            ucf&.user&.username, "notice_#{obj['group'].downcase}", {
              groupname: obj['group'],
              username: ucf&.user&.name || ucf&.user&.username,
              date: obj['expires'],
            }
          )
          obj['status'] = 'expiring'
          ucf['value'] = JSON.generate(obj)
          ucf.save!
        end

        if (obj['expires'] < now) && (status != 'inactive')
          # remove user from group
          user = ucf.user
          group = Group.where(name: obj['group']).first
          if group.nil?
            Rails.logger.error("Could not find group name #{obj['group']}")
          else
            group.remove(user)
          end

          # send notification for deactivated
          ::GroupExpiration::Utils::send_pm(
            ucf&.user&.username, "expired_#{obj['group'].downcase}", {
              groupname: obj['group'],
              username: ucf&.user&.name || ucf&.user&.username,
              date: obj['expires'],
            }
          )

          obj['status'] = 'inactive'
          ucf['value'] = JSON.generate(obj)
          ucf.save!
        end
      end
    end
  end
end