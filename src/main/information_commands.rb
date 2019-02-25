# Crystal: InformationCommands


# This crystal contains commands that display the info of AaravosBot, a user, role or the server.
module Bot::InformationCommands
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Gets info of AaravosBot
  command :info do |event|
    # Sends embed containing the bot's info
    event.send_embed do |embed|
      embed.author = {
          name:     'AaravosBot: Info',
          icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
      }
      embed.description = "AaravosBot is the custom bot for the Dragon Prince server.\n" +
                          "He was initially written for the functionality of <#506866876417048586>, but has since evolved into much more.\n" +
                          "He is coded using the [Ruby](https://www.ruby-lang.org/en/) language, using the [discordrb](https://github.com/meew0/discordrb) library and the [Cluster](https://github.com/410757864530-dead-salmonids/cluster) bot framework.\n" +
                          "He is not hosted on any VPS or other hosting service, just my (<@220509153985167360>'s) home PC.\n" +
                          "His icon was made lovingly by <@139198446799290369>.\n" +
                          "\n" +
                          "Source code can be found [here](https://github.com/410757864530-dead-salmonids/aaravosbot)"
      embed.footer = {text: '"How may I serve you?" • Created on October 30, 2018'}
      embed.color = 0xFFD700
    end
  end

  # Gets info of a user
  command :userinfo, aliases: [:whois, :who] do |event, *args|
    # Gets user object from argument, using event user if arg is empty
    user = args.empty? ? event.user : SERVER.get_user(args.join(' '))

    # If user is valid, sends embed containing all necessary information
    if user
      event.send_embed do |embed|
        embed.author = {
          name: "USER: #{user.display_name} (#{user.distinct})",
          icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.thumbnail = {url: user.avatar_url}
        embed.add_field(
          name: 'Created Account',
          value: user.creation_time.strftime('%B %-d, %Y'),
          inline: true
        )

        join_index = SERVER.members.reject { |u| u.bot_account || !u.joined_at }.sort_by { |u| u.joined_at }.index { |u| u == user }
        join_position_text = join_index ? " (position #{join_index + 1})" : nil

        embed.add_field(
          name: 'Joined Server',
          value: "#{user.joined_at ? user.joined_at.strftime('%B %-d, %Y') : 'Not found (cache issue)'}#{join_position_text}",
          inline: true
        )
        embed.add_field(
          name: 'Roles',
          value: user.roles.map { |r| r.mention }.join(', ')
        )
        embed.footer = {text: "ID: #{user.id}"}
        embed.color = 0xFFD700
      end

    # Otherwise, respond that user can't be found
    else
      event.send_temp(
        "That user can't be found.",
        5 # seconds to delete
      )
    end
  end

  # Gets info of the server
  command :serverinfo do |event|
    # Sends embed containing server info
    event.send_embed do |embed|
      embed.author = {
        name: "SERVER: #{SERVER.name}",
        icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
      }
      embed.thumbnail = {url: SERVER.icon_url}
      embed.add_field(
        name: 'Owner',
        value: "#{SERVER.owner.display_name} (#{SERVER.owner.distinct})",
        inline: true
      )
      embed.add_field(
        name: 'Creation Date',
        value: SERVER.creation_time.strftime('%B %-d, %Y'),
        inline: true
      )
      embed.add_field(
        name: 'Region',
        value: SERVER.region_id,
        inline: true
      )
      embed.add_field(
        name: 'Channels',
        value: "**Total: #{SERVER.channels.size} on server**\n" +
               "• **#{SERVER.text_channels.size}** text channels\n" +
               "• **#{SERVER.voice_channels.size}** voice channels\n" +
               "• **#{SERVER.categories.size}** channel categories",
        inline: true
      )
      embed.add_field(
        name: 'Members',
        value: "**Total: #{SERVER.member_count} on server** *(#{SERVER.online_members.size} online)*\n" +
               "• **#{SERVER.members.count { |u| !u.bot_account? }}** users\n" + 
               "• **#{SERVER.members.count { |u| u.bot_account? }}** bots",
        inline: true
      )
      embed.add_field(
        name: 'Roles',
        value: "**#{SERVER.roles.size}** roles on server",
        inline: true
      )
      embed.footer = {text: "ID: #{SERVER.id}"}
      embed.color = 0xFFD700
    end
  end


  # Gets info of a role
  command :roleinfo do |event, *args|
    # Gets the role that matches the given name or ID, preferring ID
    role = SERVER.roles.find do |role|
      role.id == args.join.to_i || role.name.downcase == args.join(' ').downcase
    end

    # If a valid role was found:
    if role
      # Sends embed containing role info
      msg = event.send_embed do |embed|
        embed.author = {
            name: "ROLE: #{role.name}",
            icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.thumbnail = {url: SERVER.icon_url}
        embed.add_field(
            name: 'Color',
            value: "##{role.color.hex.rjust(6, '0')}",
            inline: true
        )
        embed.add_field(
            name: 'Members',
            value: "**#{role.members.count}** have this role",
            inline: true
        )

        # Gets objects for roles directly above and below the given role
        role_above = SERVER.roles.find { |r| r.position == role.position + 1 }
        role_below = SERVER.roles.find { |r| r.position == role.position - 1 }

        embed.add_field(
            name: 'Position',
            value: "**Position: #{role.position}**\n" +
                "• Directly below #{role_above ? role_above.mention : 'nothing'}\n" +
                "• Directly above #{role_below ? role_below.mention : 'nothing'}",
            inline: true
        )
        embed.add_field(
            name: 'Other attributes',
            value: "• **Hoisted?** #{role.hoist ? 'Yes' : 'No'}\n" +
                "• **Mentionable?** #{role.mentionable ? 'Yes' : 'No'}",
            inline: true
        )
        embed.footer = {text: "ID: #{role.id}"}
        embed.color = role.color.combined
      end

      # Adds reaction controls to sent embed
      msg.reaction_controls(event.user, 0..(SERVER.roles.size - 1), 30, role.position) do |index|
        role = SERVER.roles.find { |r| r.position == index }
        role_above = SERVER.roles.find { |r| r.position == role.position + 1 }
        role_below = SERVER.roles.find { |r| r.position == role.position - 1 }

        msg.edit(
            '', # no content
            {
                author: {
                    name: "ROLE: #{role.name}",
                    icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
                },
                thumbnail: {url: SERVER.icon_url},
                fields: [
                    {
                        name: 'Color',
                        value: "##{role.color.hex.rjust(6, '0')}",
                        inline: true
                    },
                    {
                        name: 'Members',
                        value: "**#{role.members.count}** have this role",
                        inline: true
                    },
                    {
                        name: 'Position',
                        value: "**Position: #{role.position}**\n" +
                            "• Directly below #{role_above ? role_above.mention : 'nothing'}\n" +
                            "• Directly above #{role_below ? role_below.mention : 'nothing'}",
                        inline: true
                    },
                    {
                        name: 'Other attributes',
                        value: "• **Hoisted?** #{role.hoist ? 'Yes' : 'No'}\n" +
                            "• **Mentionable?** #{role.mentionable ? 'Yes' : 'No'}",
                        inline: true
                    }
                ],
                footer: {text: "ID: #{role.id}"},
                color: role.color.combined
            }
        )
      end

    # Otherwise, respond that role can't be found
    else
      event.send_temp(
          "That role can't be found.",
          5 # seconds to delete
      )
    end
  end

  # Help command info for every command in this crystal
  module HelpInfo
    extend HelpCommand

    # +info
    command_info(
        name: :info,
        blurb: 'Gets info on AaravosBot.',
        permission: :user,
        info: ["Returns info about AaravosBot, such as the language he is coded in, the libraries he uses and a link to his source code."],
        group: :information,
    )

    # +userinfo
    command_info(
        name: :userinfo,
        blurb: 'Gets info on a user.',
        permission: :user,
        info: [
            "Returns an embed of a user's info, including their ID, join dates and roles.",
            "Can take an argument, otherwise returns your own info."
        ],
        usage: [
            [nil, 'Gets your own user info.'],
            ['<user>', "Gets another user's info. Can accept IDs, usernames or nicknames."]
        ],
        group: :information,
        aliases: [:whois, :who]
    )

    # +serverinfo
    command_info(
        name: :serverinfo,
        blurb: 'Gets info on the server.',
        permission: :user,
        info: ["Returns an embed of the server's info, including its ID, owner, region, channels, members and roles."],
        group: :information
    )

    # +roleinfo
    command_info(
        name: :roleinfo,
        blurb: 'Gets info on a role.',
        permission: :user,
        info: [
            'Returns an embed of a role, including its ID, color, member count, position and other attributes.',
            'You can also navigate the list with reaction buttons!'
        ],
        usage: [
            ['<role>', "Gets a role's info. Can accept IDs or names."]
        ],
        group: :information
    )
  end
end