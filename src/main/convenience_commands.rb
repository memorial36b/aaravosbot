# Crystal: ConvenienceCommands


# This crystal implements my custom help command and the +myperms command for my bot testing.
# This is integrated with some functions in the `utils.rb` lib file, so ensure that's there.
module Bot::ConvenienceCommands
  extend Discordrb::Commands::CommandContainer
  extend HelpCommand
  include Constants

  # #music channel ID
  MUSIC_ID = 492864853401141259
  
  # Help command
  command :help do |event, arg|
    # Breaks if command is executed in #music
    break if event.channel.id == MUSIC_ID

    user_permission = if event.user.has_permission?(:administrator)
                        'Administrator'
                      elsif event.user.has_permission?(:moderator)
                        'Moderator'
                      else 'User'
                      end
    user_permission += ' [Ink]' if event.user.id == MY_ID

    # If an argument was given:
    if arg
      # If a command with the name of the given argument exists:
      if help[(com = arg.to_sym)]
        # If user has permission to use the command, respond with an embed containing the command info
        if event.user.has_permission?(help[com][:permission])
          info = help[com]

          event.send_embed do |embed|
            embed.author = {
                name:     "Help: +#{com}",
                icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
            }
            embed.color = 0xFFD700
            embed.description = "#{info[:info]}\n" +
                                "\n" +
                                "**Permission needed:** #{info[:permission].to_s.capitalize}"
            embed.add_field(
                name:  'Usage',
                value: info[:usage]
            )
            if info[:aliases]
              embed.add_field(
                name:  'Aliases',
                value: info[:aliases].map { |a| "+#{a}" }.join(", ")
              )
            end
            embed.footer = {text: 'Use +help to get a list of commands available to your permission level.'}
          end

        # If user does not have permission to use the command, respond to user
        else event.channel.send_temp("You don't have permission to view that command.", 5)
        end

      # If no command with the name of the given argument exists, respond to user
      else event.channel.send_temp('That command does not exist.', 5)
      end

    # If no argument was given (view the full command list), respond with embed containing the command listing
    else
      event.channel.send_embed do |embed|
        embed.author = {
            name:     'Help: Command List',
            icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.color = 0xFFD700
        embed.description = "This is the list of commands available for your permission level: **#{user_permission}**.\n" +
                            "Commands are grouped by category."
        grouped_help = Hash.new { |h, k| h[k] = Hash.new }
        aliases_skip = []
        help.each do |key, data|
          if event.user.has_permission?(data[:permission]) &&
             !aliases_skip.include?(key)
            grouped_help[data[:group]][key] = data[:blurb]
            aliases_skip += data[:aliases] if data[:aliases]
          end
        end
        grouped_help.each do |group, commands|
          embed.add_field(
              name:   group.to_s.split('_').map(&:capitalize).join(' '),
              value:  commands.map { |c, b| "• `+#{c}` - #{b}" }.join("\n"),
              inline: true
          )
        end
        embed.footer = {text: 'Use +help [command] to get more detailed info on a specific command.'}
      end
    end
  end

  # Command to set my (Ink's) perms locally
  command :myperms do |event, arg = ''|
    # Breaks unless I am the one using the command
    break unless event.user.id == MY_ID

    # Cases argument and defines my local permissions accordingly, and responds to me
    case arg.downcase
    when 'administrator', 'admin'
      Discordrb::Member.bot_owner_permission = :administrator
      event << '**Set your command permission level to `Administrator`.**'
    when 'moderator', 'mod'
      Discordrb::Member.bot_owner_permission = :moderator
      event << '**Set your command permission level to `Moderator`.**'
    when 'user', 'public'
      Discordrb::Member.bot_owner_permission = :user
      event << '**Set your command permission level to `User`.**'
    else event.send_temp('Invalid argument.', 5)
    end
  end

  # Help command info for every command in this crystal
  module HelpInfo
    extend HelpCommand

    # +help
    command_info(
        name: :help,
        blurb: "That's me, hi there!",
        permission: :user,
        info: [
            'A command that displays a list of all bot commands available to you, or more detailed info on a specific command.',
            'Only commands you are able to use are visible (i.e. some commands are only available to moderators).'
        ],
        usage: [
            [nil, 'Displays a list of all commands available to you, based on your permission level.'],
            ['<command>', 'Displays detailed info on a specific command.']
        ]
    )

    # +myperms
    command_info(
        name: :myperms,
        blurb: "Sets Ink's permission level.",
        permission: :ink,
        info: [
            "Sets Ink's permission level for testing purposes to User, Moderator or Administrator",
            'Note that this is for bot testing purposes ONLY: Ink is NOT a staff member!'
        ],
        usage: [
            ['+myperms <level>', 'Sets my permission level to specified level; can be `admin/administrator`, `mod/moderator`, or `public/user`.']
        ]
    )
  end
end