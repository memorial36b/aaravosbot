# Crystal: AssignableRoles


# This crystal handles the assignable role system. in which moderators can set certain roles
# to be self-assignable by users through bot commands.
module Bot::AssignableRoles
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Assignable roles dataset
  ASSIGNABLE_ROLES = DB[:assignable_roles]
  
  # Master command for assignable roles
  command :roles do |event, *args|
    # Sets default argument to info
    args[0] ||= 'info'

    # If user wants to add a role, is a moderator, and role key and name have been given:
    if args[0].downcase == 'add' &&
       event.user.has_permission?(:moderator) &&
       args.size >= 3 # ensures role key and name have been given

      # If an assignable role with the given key already exists, responds to user
      if ASSIGNABLE_ROLES[key: (key = args[1].downcase)]
        event << "**ERROR:** Key `#{key}` has already been assigned to a role."

      # If the key is valid and a role with the given name exists:
      elsif (role = SERVER.roles.find { |r| r.name.downcase == args[2..-1].join(' ').downcase })
        # Adds role entry to the database
        ASSIGNABLE_ROLES << {
            key:   args[1].downcase,
            id:    role.id,
            group: 'No Group'
        }

        # Responds to user
        event << "**Made role #{role.name} assignable with key `#{key}`.**"

      # If no role with the given name exists, responds to user
      else
        event << "**ERROR:** Role `#{args[2..-1].join(' ')}` not found."
      end

    # If user wants to set a role's group, is a moderator, and the role key and group have been given:
    elsif args[0].downcase == 'group' &&
          event.user.has_permission?(:moderator) &&
          args.size >= 3 # ensures role key and group have been given
      # If a role with the given key exists in the database:
      if (entry = ASSIGNABLE_ROLES[key: (key = args[1].downcase)])
        role = SERVER.role(entry[:id])
        group = args[2..-1].map(&:capitalize).join(' ')

        # Updates role entry in the database with the new group
        ASSIGNABLE_ROLES.where(entry).update(group: (group == 'None') ? 'No Group' : group)

        # Responds to user
        event << "**Set group of role #{role.name} (key `#{key}`) to #{group}.**"

      # If no role with the given key exists in the database, responds to user:
      else
        event << "**ERROR:** Role with key `#{key}` not found."
      end

    # If user wants to remove a role, is a moderator and the role key has been given:
    elsif args[0].downcase == 'remove' &&
          event.user.has_permission?(:moderator) &&
          args.size >= 2 # ensures role key has been given
      # If a role with the given key exists in the database:
      if (entry = ASSIGNABLE_ROLES[key: (key = args[1].downcase)])
        role = SERVER.role(entry[:id])

        # Deletes role entry from database
        ASSIGNABLE_ROLES.where(entry).delete

        # Responds to user
        event << "**Removed role #{role.name} from being assignable with key `#{key}`.**"

      # If no role with the given key exists in the database, responds to user
      else
        event << "**ERROR:** Role with key `#{key}` not found."
      end

    # If user wants to set a role's description, is a moderator, and the role key has been given:
    elsif %w(desc description).include?(args[0].downcase) &&
          event.user.has_permission?(:moderator) &&
          args.size >= 2
      # If a role with the given key exists in the database:
      if (entry = ASSIGNABLE_ROLES[key: (key = args[1].downcase)])
        # If no description is given:
        if args[2..-1].empty?
          # Updates role entry in the database with the new (nil) description
          ASSIGNABLE_ROLES.where(entry).update(desc: nil)

          # Responds to user
          event << "**Deleted description of role #{SERVER.role(entry[:id]).name} (key `#{key}`).**"
        else
          desc = args[2..-1].join(' ')

          # Updates role entry in the database with the new description
          ASSIGNABLE_ROLES.where(entry).update(desc: desc)

          # Responds to user
          event << "**Set description of role #{SERVER.role(entry[:id]).name} (key `#{key}`) to `#{desc}`.**"
        end

      # If no role with the given key exists in the database, responds to user
      else
        event << "**ERROR:** Role with key `#{key}` not found."
      end

    # If user wants to check the list of assignable roles, sends embed containing the info
    elsif args[0].downcase == 'info'
      role_groups = ASSIGNABLE_ROLES.map(:group).uniq

      event.send_embed do |embed|
        embed.author = {
          name:     'Roles: Info',
          icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.description = "These are the roles that you can add to yourself using their respective commands.\n" +
                            "If the role is in a named group, you can only have one role from that group at a time!\n" +
                            "To remove a role from yourself, simply use its command again."
        role_groups.each do |group|
          embed.add_field(
            name:   group,
            value:  ASSIGNABLE_ROLES.where(group: group).map([:key, :id, :desc]).map do |key, id, desc|
                      "• `+#{key}` - **#{SERVER.role(id).name}**#{desc ? ": #{desc}" : nil}"
                    end.join("\n"),
            inline: true
          )
          embed.color = 0xFFD700
          embed.footer = {text: 'This list is kept updated with any changes to assignable roles.'}
        end
      end
    end
  end
  
  # Detects when a user has entered the command for an assignable role
  message(start_with: '+') do |event|
    # Skips unless the command entered has an entry in the database
    next unless (entry = ASSIGNABLE_ROLES[key: event.message.content[1..-1].downcase])

    role = SERVER.role(entry[:id])
    group = entry[:group]

    # If user is removing their role:
    if event.user.role?(role)
      # Removes role and responds to user
      event.user.remove_role(role)
      event << "**#{event.user.mention}, your #{role.name} role has been removed.**"

    # If user is adding a role:
    else
      # Removes all other roles in the group from the user unless role is not in a group
      event.user.remove_role(ASSIGNABLE_ROLES.where(group: group).map(:id)) unless group == 'No Group'

      # Adds role and responds to user
      event.user.add_role(role)
      event << "**#{event.user.mention}, you have been given the #{role.name} role.**"
    end
  end

  # Help command info for every command in this crystal
  module HelpInfo
    extend HelpCommand

    # +roles
    command_info(
        name:       :roles,
        blurb:      'Command used for self-assignable roles.',
        permission: :user,
        info: [
            'Master command for getting info on and setting up self-assignable roles.',
            'Use `+roles` to get info on how to assign yourself a role.',
            'The commands used to add, remove, group and add a description to assignable roles are exclusive to moderators.'
        ],
        usage: [
            ['info', 'Displays info on all available assignable roles and what their commands are. `+roles` with no arguments defaults to this.'],
            ['add <key> <role name>', 'Makes the role with the provided name assignable with the specified "command key". This also functions as its command.'],
            ['group <key> <role name>', 'Sets the role that has the given key to be part of the specified group. When a role is part of a group, users can only have one role of the group at a time. Set group equal to `none` to remove it from a group.'],
            ['remove <key>', 'Removes the role that has the given key from being self-assignable.'],
            ['[description/desc] <key> <description>', 'Adds a description to the role with the given key, displayed in the info command. Use without a description to delete the existing description.']
        ]
    )
  end
end