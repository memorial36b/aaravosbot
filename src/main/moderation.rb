# Crystal: Moderation


# This crystal contains commands and other security features meant for server moderation, and thus
# are generally limited to server staff.
module Bot::Moderation
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Muted (users) dataset
  MUTED = DB[:muted]
  # Scheduler constant
  SCHEDULER = Rufus::Scheduler.new
  # Muted channel ID
  MUTED_CHANNEL_ID = 541809796911726602
  # #mod_log ID
  MOD_LOG_ID = 545113155831988235

  # Commands module from discordrb
  module Discordrb::Commands
    # Bucket class from discordrb
    class Bucket
      # Resets the number of requests by a thing
      def reset(thing)
        # Resolves key and deletes its entry in the bucket hash
        key = resolve_key thing
        @bucket.delete(key)
      end
    end

    module RateLimiter
      # Resets the number of requests by a thing 
      def reset(key, thing)
        # Do nothing unless the bucket actually exists
        if @buckets && @buckets[key]
          # Execute reset method
          @buckets[:key].reset(thing)
        end
      end
    end
  end

  module_function

  # Takes the given time string argument, in a format similar to '5d2h15m45s' and returns its representation in
  # a number of seconds.
  # @param  [String]  str the string to parse into a number of seconds
  # @return [Integer]     the number of seconds the given string is equal to, or 0 if it cannot be parsed properly
  def parse_time(str)
    seconds = 0
    str.scan(/\d+ *[Dd]/).each { |m| seconds += (m.to_i * 24 * 60 * 60) }
    str.scan(/\d+ *[Hh]/).each { |m| seconds += (m.to_i * 60 * 60) }
    str.scan(/\d+ *[Mm]/).each { |m| seconds += (m.to_i * 60) }
    str.scan(/\d+ *[Ss]/).each { |m| seconds += (m.to_i) }
    seconds
  end

  # Takes the given number of seconds and converts into a string that describes its length (i.e. 3 hours,
  # 4 minutes and 5 seconds, etc.)
  # @param  [Integer] secs the number of seconds to convert
  # @return [String]       the length of time described
  def time_string(secs)
    dhms = ([secs / 86400] + Time.at(secs).utc.strftime('%H|%M|%S').split("|").map(&:to_i)).zip(['day', 'hour', 'minute', 'second'])
    dhms.shift while dhms[0][0] == 0
    dhms.pop while dhms[-1][0] == 0
    dhms.map! { |(v, s)| "#{v} #{s}#{v == 1 ? nil : 's'}" }
    return dhms[0] if dhms.size == 1
    "#{dhms[0..-2].join(', ')} and #{dhms[-1]}"
  end

  raid_config = YAML.load_data!("#{Bot::DATA_PATH}/raid_mode_settings.yml")
  raid_bucket = Bot::BOT.bucket(
      :raid,
      limit: raid_config[:users] - 1,
      time_span: raid_config[:seconds]
  )
  flood_config = YAML.load_data!("#{Bot::DATA_PATH}/flood_settings.yml")
  flood_bucket = Bot::BOT.bucket(
      :flood,
      limit: flood_config[:messages] - 1,
      time_span: flood_config[:seconds]
  )
  raid_mode_active = false
  raid_users = Array.new
  mute_jobs = Hash.new

  # Schedules unmute jobs for every user currently in the mute database upon starting the bot
  ready do
    # Iterates through all entries in the mute database
    MUTED.all do |entry|
      # Schedules Rufus job at the end time of the mute, and stores its ID in the job hash
      mute_jobs[entry[:id]] = SCHEDULER.at Time.at(entry[:end_time]) do
        # Unmutes the user, catching and logging any exceptions in case issues arise
        begin
          SERVER.member(entry[:id]).modify_roles(
              MEMBER_ID, # adds Member
              MUTED_ID   # removes Muted
          )
        rescue StandardError
          puts 'Exception raised when unmuting user -- likely user left server'
        end

        # Deletes user entry from job hash and database
        mute_jobs.delete(entry[:id])
        MUTED.where(entry).delete
      end
    end
  end

  # Re-mutes user if they leave the server and rejoin during their mute
  member_join do |event|
    # Skips unless user is muted
    next unless MUTED[id: event.user.id]

    # Short delay before modifying roles to allow Mee6 to give user the member role;
    # otherwise user will have the role added before Aaravos is able to remove it
    sleep 3
    event.user.modify_roles(
        MUTED_ID, # adds Muted
        MEMBER_ID # removes Member
    )
  end

  # Warns a user
  command :warn, aliases: [:warning] do |event, *args|
    # Breaks unless user is moderator and given user is valid, defining user variable if so
    break unless event.user.has_permission?(:moderator) &&
                 (user = SERVER.get_user(args.join(' ')))

    msgs = Array.new

    # Prompts user for warning message, pushes prompt and response to message array and defines reason variable
    msg = event.respond '**What should the warning message be?** Press ❌ to cancel.'
    msg.react('❌')
    msgs.push(msg)

    # Defines two awaits in separate threads so they work in parallel, sleeps command thread until either returns
    # a response, and sets reason
    reason = nil
    Thread.new do
      reason = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '❌')
        break :cancel if await_event.user == event.user
      end
    end
    Thread.new do
      await_event = event.message.await!
      msgs.push(await_event.message)
      reason = await_event.message.content
    end
    sleep 0.05 until reason

    # Deletes all temporary messages
    msgs.each { |m| m.delete }

    # Breaks command and sends cancellation message to event channel if user canceled warning
    break '**Canceled warning.**' if reason == :cancel

    # Sends log embed to #mod_log
    Bot::BOT.channel(MOD_LOG_ID).send_embed do |embed|
      embed.author = {
          name: "WARNING | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = "⚠ **#{user.mention} was issued a warning by #{event.user.mention}.**\n" +
                          "**Reason:** #{reason}\n" +
                          "\n" +
                          "**Issued by:** #{event.user.mention} (#{event.user.distinct})"
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    # DMs warning message to user
    user.dm "**You've recieved a warning from one of the staff members.**\n" +
            "**Reason:** #{reason}"

    # Responds to command
    event << "**Sent warning to #{user.distinct}.**"
  end

  # Mutes a user
  command :mute do |event, *args|
    # Breaks unless user is moderator and given user is valid
    break unless event.user.has_permission?(:moderator) &&
                 (user = SERVER.get_user(args.join(' ')))

    msgs = Array.new

    # Prompts user for the length of time for the mute, pushing prompt to the message array
    msg = event.respond '**How long should the mute last?** Press ❌ to cancel.'
    msg.react('❌')
    msgs.push(msg)

    # Defines two awaits in separate threads so they work in parallel and sleeps command thread until either returns
    # a response
    mute_response = nil
    Thread.new do
      mute_response = loop do
        await_event = event.message.await!
        break if mute_response
        msgs.push(await_event.message)
        break await_event.message.content if parse_time(await_event.message.content) >= 10
        event.send_temporary_message(
            "That's not a valid length of time.",
            5 # seconds to delete
        )
      end
    end
    Thread.new do
      mute_response = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '❌')
        break :cancel if await_event.user == event.user
      end
    end
    sleep 0.05 until mute_response

    # Deletes all messages in array, breaks command and responds to command if user canceled mute
    if mute_response == :cancel
      msgs.each { |m| m.delete }
      break '**Canceled mute.**'
    end

    mute_length = parse_time(mute_response)

    # Prompts user whether they would like to input a reason, reacts with an X, and adds the prompt to
    # message variable
    msg = event.respond '**Would you like to input a reason for the mute?** Press 🔇 if not, otherwise reply with the reason.'
    msg.react('🔇')
    msgs.push(msg)

    # Defines two awaits in separate threads so they work in parallel, sleeps command thread until either returns
    # a response, and sets reason text
    reason_text = nil
    Thread.new do
      reason_text = loop do
        await_event = Bot::BOT.add_await!(Discordrb::Events::ReactionAddEvent, emoji: '🔇')
        break '' if await_event.user == event.user
      end
    end
    Thread.new do
      await_event = event.message.await!
      msgs.push(await_event.message)
      reason_text = "\n**Reason:** #{await_event.message.content}"
    end
    sleep 0.05 until reason_text

    end_time = Time.now + mute_length

    # Deletes all messages in array
    msgs.each { |m| m.delete }

    # Unschedules previous Rufus job, if any existed
    SCHEDULER.job(mute_jobs[user.id]).unschedule if mute_jobs[user.id]

    # Mutes user and adds them to mute database
    user.modify_roles(
        MUTED_ID, # adds Muted
        MEMBER_ID # removes Member
    )
    MUTED.set_new(
        {id:       user.id},
         end_time: end_time.to_i
    )

    # Schedules Rufus job to unmute user, storing its ID in hash
    mute_jobs[user.id] = SCHEDULER.at end_time do
      # Unmutes the user, catching and logging any exceptions in case issues arise
      begin
        user.modify_roles(
            MEMBER_ID, # adds Member
            MUTED_ID   # removes Muted
        )
      rescue StandardError
        puts 'Exception raised when unmuting user -- likely user left server'
      end

      # Deletes user entry from job hash and database
      mute_jobs.delete(user.id)
      MUTED.where(id: user.id).delete
    end

    # Sends log embed to #mod_log
    Bot::BOT.channel(MOD_LOG_ID).send_embed do |embed|
      embed.author = {
          name: "MUTE | User: #{user.display_name} (#{user.distinct})",
          icon_url: user.avatar_url
      }
      embed.description = "🔇 **#{user.mention} was muted for #{time_string(mute_length)}.**#{reason_text}\n" +
                          "\n" +
                          "**Muted by:** #{event.user.mention} (#{event.user.distinct})"
      embed.timestamp = Time.now
      embed.color = 0xFFD700
    end

    # Responds with notification message to muted channel
    Bot::BOT.send_message(
        MUTED_CHANNEL_ID,
        "**#{user.mention}, you've been muted for #{time_string(mute_length)}.**#{reason_text}"
    )

    # Responds to command
    event << "**Muted #{user.distinct}.**"
  end

  command :unmute do |event, *args|
    # Breaks unless user is moderator, given user is valid and is currently muted
    break unless event.user.has_permission?(:moderator) &&
                 (user = SERVER.get_user(args.join(' '))) &&
                 (entry = MUTED[id: user.id])

    # Unmutes user, unschedules Rufus job and deletes user from mute database
    user.modify_roles(
        MEMBER_ID, # adds Member
        MUTED_ID   # removes Muted
    )
    SCHEDULER.job(mute_jobs[user.id]).unschedule
    mute_jobs.delete(user.id)
    MUTED.where(entry).delete

    # Responds to command
    event << "**Unmuted #{user.distinct}.**"
  end
  
  # Purge command
  command :purge do |event, *args|
    # Breaks unless user is a moderator, the number of messages to scan is given and is between 1 and 100
    break unless event.user.has_permission?(:moderator) &&
                 args.size >= 1 &&
                 (1..100).include?(args[0].to_i)

    # Deletes event message
    event.message.delete

    # If no extra arguments were given, gets the given number of messages in this channel's history
    if args.size == 1
      messages_to_delete = event.channel.history(args[0].to_i)

    # If the extra arguments begin and end with quotation marks, scans the given number of messages in this
    # channel's history and selects the ones containing the text within the quotation marks
    elsif args.size > 1 &&
          args[1..-1].join(' ')[0] == "\"" &&
          args[1..-1].join(' ')[-1] == "\""
      text = args[1..-1].join(' ')[1..-2]
      messages_to_delete = event.channel.history(args[0].to_i).select { |m| m.content.downcase.include?(text.downcase) }

    # If the extra arguments are able to find a valid user, scans the given number of messages in this
    # channel's history and selects the ones from the user
    elsif args.size > 1 &&
          (user = SERVER.get_user(args[1..-1].join(' ')))
      messages_to_delete = event.channel.history(args[0].to_i).select { |m| user && m.author.id == user.id }

    # Otherwise, respond to command
    else event.send_temp('User not found.', 5)
    end

    # If no messages with the given parameters were found to purge, responds to command accordingly
    if (count = messages_to_delete.size) == 0
      if text event.channel.send_temp('No messages containing that text were found to purge.', 5)
      else event.channel.send_temp('No messages from that user were found to purge.', 5)
      end

    # Otherwise, deletes the selected messages and responds to command
    else
      if count == 1
        messages_to_delete[0].delete
      else event.channel.delete_messages(messages_to_delete)
      end
      message_text = if text
                       "Searched **#{pl(count, 'message')}** and deleted **#{count}** containing the text `#{text}`."
                     elsif user
                       "Searched **#{pl(count, 'message')}** and deleted **#{count}** from user `#{user.distinct}`."
                     else "Deleted **#{count}** messages."
                     end
      event.send_temp(message_text, 5)
    end
  end


  # Automatically mutes users if raid mode is active, and activates raid mode if bucket is triggered
  member_join do |event|
    # If raid mode is active when the user joins:
    if raid_mode_active
      # Short delay to allow Mee6 to give user the member role; otherwise user will have the role
      # added before Aaravos is able to remove it
      sleep 3

      # Adds user object to tracker variable
      raid_users.push(event.user)

      # Mutes user
      event.user.on(SERVER).modify_roles(MUTED_ID, MEMBER_ID)

    # Otherwise, activate raid mode if bucket is activated (the specified number of users have
    # joined in the specified amount of time)
    else
      if raid_bucket.rate_limited?(:join)
        # Set raid mode to active
        raid_mode_active = true

        # Reset the raid bucket, so further requests don't continue triggering it
        raid_bucket.reset(:join)
      end
    end
  end

  
  # Disables raid mode
  command :unraid do |event|
    # Breaks unless user is moderator and raid mode is active
    break unless event.user.has_permission?(:moderator) &&
                 raid_mode_active

    # Iterates through every raid user and unmutes them if they are still present within the server
    raid_users.each do |user|
      event.user.on(SERVER).modify_roles(MEMBER_ID, MUTED_ID) if SERVER.member(user.id)
    end

    # Clears raid users array
    raid_users = Array.new

    # Disables raid mode and responds to command
    raid_mode_active = false
    event << '**Raid mode disabled.**'
  end

  # Allows to check and set the config options for raid mode
  command :raidconfig do |event, *args|
    # Breaks unless user is moderator
    break unless event.user.has_permission?(:moderator)
    
    # Sets default argument to check
    args[0] ||= 'check'

    # If user wants to check the current config, sends embed containing the info
    if args[0].downcase == 'check'
      event.send_embed do |embed|
        embed.author = {
          name: 'Raid: Current Configuration',
          icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.description = "**Users:** #{raid_config[:users]}\n" +
                            "**Seconds:** #{raid_config[:seconds]}\n" +
                            "*(If #{raid_config[:users]} users join in #{raid_config[:seconds]} seconds, raid mode activates.)*"
        embed.footer = {text: 'To change the config options, use `+raidconfig set [option]`.'}
        embed.color = 0xFFD700
      end

    # If user wants to change a config option and both the option to set and what to set it to are given:
    elsif args[0].downcase == 'set' && 
          args.size == 3 # ensures both options are given
      # If user wants to set the number of user joins to trigger raid mode and the number is valid:
      if args[1].downcase == 'users' &&
         (value = args[2].to_i) > 0
        # Updates the data in the config file and the hash
        YAML.load_data!("#{Bot::DATA_PATH}/raid_mode_settings.yml") { |s| s[:users] = value }
        raid_config[:users] = value
        
        # Overwrite existing raid bucket with new settings
        raid_bucket = Bot::BOT.bucket(
          :raid,
          limit: value - 1,
          time_span: raid_config[:seconds]
        )

        # Responds to command
        event << "**Set the user joins needed to trigger raid mode to #{value}.**"

      # If user wants to set the time span in which enough user joins will trigger raid mode
      # and the number is valid:
      elsif args[1].downcase == 'seconds' &&
            (value = args[2].to_i) > 0
        # Updates the data in the config file and the hash
        YAML.load_data!("#{Bot::DATA_PATH}/raid_mode_settings.yml") { |s| s[:seconds] = value }
        raid_config[:seconds] = value
        
        # Overwrite existing raid bucket with new settings
        raid_bucket = Bot::BOT.bucket(
          :raid,
          limit: raid_config[:users] - 1,
          time_span: value
        )

        # Responds to command
        event << "**Set the time span in which enough user joins will trigger raid mode to #{value} seconds.**"
      end
    end
  end

  # Automatically deletes messages if user sends enough in too short of a time
  message do |event|
    # Skips unless a user has triggered the flood bucket 
    next unless flood_bucket.rate_limited?(event.user.id)

    # Resets flood bucket for user before deleting messages, so it isn't rate limited
    flood_bucket.reset(event.user.id)

    # Gets the user's message history in the event channel and deletes it
    user_messages = event.channel.history(50).select { |m| m.author == event.user }[0..flood_config[:messages]]
    event.channel.delete_messages(user_messages)
  end


  # Allows moderator to check and set the config options for message flood deletion
  command :floodconfig do |event, *args|
    # Breaks unless user is moderator
    break unless event.user.has_permission?(:moderator)

    # Sets default argument to check
    args[0] ||= 'check'

    # If user wants to check the current config, sends embed containing the info
    if args[0].downcase == 'check'
      event.send_embed do |embed|
        embed.author = {
          name: 'Flood: Current Configuration',
          icon_url: 'http://i63.tinypic.com/2w7k9b6.jpg'
        }
        embed.description = "**Messages:** #{flood_config[:messages]}\n" +
                            "**Seconds:** #{flood_config[:seconds]}\n" +
                            "*(If a user sends #{flood_config[:messages]} messages in #{flood_config[:seconds]} seconds, they are automatically deleted.)*"
        embed.footer = {text: 'To change the config options, use `+floodconfig set [option]`.'}
        embed.color = 0xFFD700
      end

      # If user wants to change a config option and both the option to set and what to set it to are given:
    elsif args[0].downcase == 'set' &&
          args.size == 3 # ensures both options are given
      # If user wants to set the number of messages to trigger deletion and the number is valid:
      if args[1].downcase == 'messages' &&
         (value = args[2].to_i) > 0
        # Updates the data in the config file and the hash
        YAML.load_data!("#{Bot::DATA_PATH}/flood_settings.yml") { |s| s[:messages] = value }
        flood_config[:messages] = value
        
        # Overwrite existing flood bucket with new settings
        flood_bucket = Bot::BOT.bucket(
          :flood,
          limit: value - 1,
          time_span: flood_config[:seconds]
        )

        # Responds to command
        event << "**Set the max messages to be sent within the defined time span to #{value}.**"

      # If user wants to set the time span in which enough messages will trigger deletion
      # and the number is valid:
      elsif args[1].downcase == 'seconds' &&
            (value = args[2].to_i) > 0
        # Updates the data in the config file and the hash
        YAML.load_data!("#{Bot::DATA_PATH}/flood_settings.yml") { |s| s[:seconds] = value }
        flood_config[:seconds] = value
        
        # Overwrite existing flood bucket with new settings
        flood_bucket = Bot::BOT.bucket(
          :flood,
          limit: flood_config[:messages] - 1,
          time_span: value
        )

        # Responds to command
        event << "**Set the time span in which enough messages will trigger deletion to #{value} seconds.**"
      end
    end
  end

  # Help command info for every command in this crystal
  module HelpInfo
    extend HelpCommand

    # +warn
    command_info(
        name: :warn,
        blurb: 'Sends a warning to a user.',
        permission: :moderator,
        info: [
            'Sends a warning to a user by DM. If a valid user is given, Aaravos will prompt for the reason.',
            'Can be canceled by pressing the X button.'
        ],
        usage: [['<user>', 'Sends a warning to the given user. Accepts IDs, mentions, nicknames and full usernames.']],
        group: :moderation,
        aliases: [:warning]
    )

    # +mute
    command_info(
        name: :mute,
        blurb: 'Mutes a user.',
        permission: :moderator,
        info: [
            'Mutes a user. If a valid user is given, Aaravos will prompt for the mute time, followed by an optional reason.',
            'Can be canceled by pressing the X button when being prompted for the mute time.'
        ],
        usage: [['<user>', 'Mutes the given user. Accepts IDs, mentions, nicknames and full usernames.']],
        group: :moderation
    )

    # +unmute
    command_info(
        name: :unmute,
        blurb: 'Unmutes a user.',
        permission: :moderator,
        info: [
            'Unmutes a user.',
            "Not much else to it -- it's pretty self-explanatory."
        ],
        usage: [['<user>', 'Unmutes the given user. Accepts IDs, mentions, nicknames and full usernames.']],
        group: :moderation
    )

    # +purge
    command_info(
        name: :purge,
        blurb: 'Deletes a number of messages from a channel.',
        permission: :moderator,
        group: :moderation,
        info: [
            'Deletes a given number of the most recent messages in the channel it is used in.',
            'Optionally can be given a user or text input, and the bot will scan through the given number of messages and delete any made by that user or contain that text.'
        ],
        usage: [
            ['<number>', 'Deletes the given number of the most recent messages.'],
            ['<number> <user>', 'Scans through the given number of messages and deletes any from the given user. Accepts user ID, mention, username (with or without discrim) or nickname.'],
            ['<number> "text"', 'Scans through the given number of messages and deletes any containing the given text. Make sure to include quotation marks!']
        ]
    )

    # +unraid
    command_info(
        name: :unraid,
        blurb: 'Disables raid mode.',
        permission: :moderator,
        info: [
            'Disables raid mode if it is currently active.',
            'New users will no longer be automatically muted upon joining.'
        ],
        group: :moderation
    )

    # +raidconfig
    command_info(
        name: :raidconfig,
        blurb: 'Used to manage configuration for raid protection.',
        permission: :moderator,
        info: [
            'Allows user to manage raid protection configuration (checking or changing settings).',
            'The options that can be set are the limit on the users that can join in a number of seconds, and that time period itself.'
        ],
        usage: [
            ['check', 'Returns what the current configuration is. This is the default for no arguments.'],
            ['set users <number>', 'Sets the limit of users that can join in the given time span.'],
            ['set seconds <number>', 'Sets the time span within which joins should be limited, in seconds.']
        ],
        group: :moderation
    )

    # +floodconfig
    command_info(
        name: :floodconfig,
        blurb: 'Used to manage configuration for message flood protection.',
        permission: :moderator,
        info: [
            'Allows user to manage message flood protection configuration (checking or changing settings).',
            'The options that can be set are the limit on the messages that can be sent by a user in a given time, and that time period itself.'
        ],
        usage: [
            ['check', 'Returns what the current configuration is. This is the default for no arguments.'],
            ['set messages <number>', 'Sets the limit of messages that can be sent in the given time span.'],
            ['set seconds <number>', 'Sets the time span within which messages should be limited, in seconds.']
        ],
        group: :moderation
    )
  end
end