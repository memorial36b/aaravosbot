# Crystal: StaffContact


# This crystal handles the "DM to contact staff" functionality of the bot.
module Bot::StaffContact
  # These two lines can be removed as needed (i.e. if your crystal does not contain any commands or event handlers)
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Chat info dataset
  CHAT_INFO = DB[:chat_info]
  # Chat message log dataset
  CHAT_MESSAGE_LOG = DB[:chat_message_log]
  # Server Staff category ID
  SERVER_STAFF = 469975485015654410
  # Chat log channel ID
  CHAT_LOG = 546471912910356480

  # Hash of event handlers for the created chat channels
  event_handlers = Hash.new

  # Iterates through every entry in the chat session database and defines event handlers for their users and channels
  ready do
    CHAT_INFO.all do |entry|
      user = Bot::BOT.user(entry[:user_id])

      # Defines event handler for channel in the given entry and stores it in hash to be removed later
      event_handlers[entry[:user_id]] = Bot::BOT.message in: entry[:channel_id] do |event|
        # Skips if the bot is the one sending the message or the message is the +end command
        next if event.user == Bot::BOT.profile ||
                event.message.content == '+end'

        # If no attachments were sent with the message, sends and logs message accordingly
        if event.message.attachments.empty?
          user.dm "**#{event.user.distinct}** | #{event.message.content}"
          CHAT_MESSAGE_LOG << {
              user_id:   entry[:user_id],
              message:   "#{event.user.distinct} - #{event.message.content}",
              timestamp: Time.now.to_i
          }

          # If attachments were sent with the message, sends and logs message accordingly
        else
          event.user.dm(
              "**#{event.user.distinct}:** #{event.message.content}\n" +
              "\n" +
              event.message.attachments.each_with_index.map { |a, i| "**Attachment #{i + 1}:** #{a.url}" }.join("\n")
          )
          CHAT_MESSAGE_LOG << {
              user_id:   entry[:user_id],
              message:   "#{event.user.distinct} - #{event.message.content}\n" +
                         event.message.attachments.each_with_index.map { |a, i| "Attachment #{i + 1}: #{a.url}" }.join("\n"),
              timestamp: Time.now.to_i
          }
        end
      end
    end
  end

  # Manages triggering staff contact upon a user sending a DM to the bot
  message private: true do |event|
    # Skips if the bot is the one sending the message
    next if event.user == Bot::BOT.profile

    # If the user has an entry in the database:
    if (entry = CHAT_INFO[user_id: event.user.id])
      # If the user has a defined channel entry:
      if entry[:channel_id]
        channel = Bot::BOT.channel(entry[:channel_id])

        # If no attachments were sent with the message, sends and logs message accordingly
        if event.message.attachments.empty?
          channel.send("**#{event.user.distinct}** | #{event.message.content}")
          CHAT_MESSAGE_LOG << {
              user_id:   entry[:user_id],
              message:   "#{event.user.distinct} - #{event.message.content}",
              timestamp: Time.now.to_i
          }

        # If attachments were sent with the message, sends and logs message accordingly
        else
          channel.send(
              "**#{event.user.distinct}:** #{event.message.content}\n" +
              "\n" +
              event.message.attachments.each_with_index.map { |a, i| "**Attachment #{i + 1}:** #{a.url}" }.join("\n")
          )
          CHAT_MESSAGE_LOG << {
              user_id:   entry[:user_id],
              message:   "#{event.user.distinct} - #{event.message.content}\n" +
                         event.message.attachments.each_with_index.map { |a, i| "Attachment #{i + 1}: #{a.url}" }.join("\n"),
              timestamp: Time.now.to_i
          }
        end
      end

    # If the user does not have an entry in the contact hash:
    else
      # Defines entry for event user in database
      CHAT_INFO << {user_id: event.user.id}

      # Prompts user for whether they would like to contact the staff, and awaits response
      msg = event.respond "**Would you like to contact the staff?**\n" +
                          "Press ✅ to start the chat. The button will expire after one minute. (This one's the beta)"
      msg.react '✅'
      response = Bot::BOT.add_await!(
          Discordrb::Events::ReactionAddEvent,
          emoji: '✅',
          channel: event.channel,
          timeout: 60
      )

      # If user would like to contact staff:
      if response
        # Logs time at which the chat session began in user's entry in database
        CHAT_INFO.where(user_id: event.user.id).update(start_time: Time.now.to_i)

        # Creates contact channel and updates channel ID record user's entry in database
        channel = SERVER.create_channel(
            "chat-#{event.user.name.scan(/\w|\s/).map { |c| c =~ /\s/ ? '_' : c }.join}-#{event.user.discrim}",
            topic:  "Chat with user #{event.user.mention}",
            parent: SERVER_STAFF,
            reason: "Chat with user #{event.user.distinct}"
        )
        CHAT_INFO.where(user_id: event.user.id).update(channel_id: channel.id)

        # Sends message pinging online staff that a user would like to speak with them
        channel.send("@here **User #{event.user.distinct} would like to speak with the staff.**")

        # Adds event handler for messages sent in the new channel and stores it in hash, so it can
        # be removed later
        event_handlers[event.user.id] = Bot::BOT.message in: channel do |subevent|
          # Skips if the bot is the one sending the message or the message is the +end command
          next if subevent.user == Bot::BOT.profile ||
                  subevent.message.content == '+end'

          # If no attachments were sent with the message, sends and logs message accordingly
          if subevent.message.attachments.empty?
            event.user.dm "**#{subevent.user.distinct}** | #{subevent.message.content}"
            CHAT_MESSAGE_LOG << {
                user_id:   event.user.id,
                message:   "#{subevent.user.distinct} - #{subevent.message.content}",
                timestamp: Time.now.to_i
            }

          # If attachments were sent with the message, sends and logs message accordingly
          else
            event.user.dm(
                "**#{subevent.user.distinct}:** #{subevent.message.content}\n" +
                "\n" +
                subevent.message.attachments.each_with_index.map { |a, i| "**Attachment #{i + 1}:** #{a.url}" }.join("\n")
            )
            CHAT_MESSAGE_LOG << {
                user_id:   event.user.id,
                message:   "#{subevent.user.distinct} - #{subevent.message.content}\n" +
                           subevent.message.attachments.each_with_index.map { |a, i| "Attachment #{i + 1}: #{a.url}" }.join("\n"),
                timestamp: Time.now.to_i
            }
          end
        end

        # DMs user that their chat session has begun
        event.respond '**Your chat session has begun. You can speak to the staff through this DM.**'

      # If response is a timeout, deletes user entry from contact hash
      else CHAT_INFO.where(user_id: event.user.id).delete
      end
    end
  end

  # Ends a chat session with a user
  command :end do |event|
    # Breaks unless the command is used in a staff contact channel
    break unless (entry = CHAT_INFO[channel_id: event.channel.id])

    user = Bot::BOT.user(entry[:user_id])
    messages = CHAT_MESSAGE_LOG.where(user_id: user.id).order(:timestamp).map(:message)

    # DMs user that their chat session has ended
    user.dm '**Your chat session with the staff has ended.**'

    # Writes chat log to file and uploads it to log channel
    File.open("#{Bot::DATA_PATH}/log.txt", 'w') do |file|
      file.write(
          "Log of chat with user #{user.distinct} at #{entry[:start_time]}\n" +
          "\n" +
          "#{messages.join("\n--------------------\n")}\n" +
          "\n" +
          "Chat ended by #{event.user.distinct}."
      )
    end
    Bot::BOT.send_file(
        CHAT_LOG,
        File.open("#{Bot::DATA_PATH}/log.txt"),
        caption: "**Log of chat with user `#{user.distinct}`**"
    )

    # Removes event handler for channel
    Bot::BOT.remove_handler(event_handlers[user.id])

    # Notifies staff that the chat has been logged and that the channel will be deleted in 5 seconds
    # and deletes channel accordingly
    event.respond '**The chat session has been logged. This channel will be deleted in 5 seconds.**'
    sleep 5
    event.channel.delete "Ended chat with #{user.distinct}"

    # Clears message log for user and deletes user entry from database
    CHAT_MESSAGE_LOG.where(user_id: user.id).delete
    CHAT_INFO.where(entry).delete

    nil # returns nil so command doesn't send a message to a nonexistent channel
  end
end