# Crystal: StaffContact


# This crystal handles the "DM to contact staff" functionality of the bot.
module Bot::StaffContact
  # These two lines can be removed as needed (i.e. if your crystal does not contain any commands or event handlers)
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Server Staff category ID
  SERVER_STAFF = 469975485015654410
  # Chat log channel ID
  CHAT_LOG = 546471912910356480

  # Contact info for any user attempting to contact staff (i.e. user's ID, their channel in the server, and a log of
  # the messages sent)
  contact_data = Hash.new

  # Manages triggering staff contact upon a user sending a DM to the bot
  message private: true do |event|
    # Skips if the bot is the one sending the message
    next if event.user == Bot::BOT.profile

    # If the user has an entry in the contact hash:
    if contact_data[event.user.id]
      # If the user has a channel entry:
      if contact_data[event.user.id][:channel]
        # If no attachments were sent with the message, sends and logs message accordingly
        if event.message.attachments.empty?
          contact_data[event.user.id][:channel].send("**#{event.user.distinct}** | #{event.message.content}")
          contact_data[event.user.id][:messages].push("#{event.user.distinct} - #{event.message.content}")

        # If attachments were sent with the message, sends and logs message accordingly
        else
          contact_data[event.user.id][:channel].send(
              "**#{event.user.distinct}:** #{event.message.content}\n" +
              "\n" +
              event.message.attachments.each_with_index.map { |a, i| "**Attachment #{i + 1}:** #{a.url}" }.join("\n")
          )
          contact_data[event.user.id][:messages].push(
              "#{event.user.distinct} - #{event.message.content}\n" +
              event.message.attachments.each_with_index.map { |a, i| "Attachment #{i + 1}: #{a.url}" }.join("\n")
          )
        end
      end

    # If the user does not have an entry in the contact hash:
    else
      # Defines entry for event user in contact hash
      contact_data[event.user.id] = Hash.new

      # Prompts user for whether they would like to contact the staff, and awaits response
      msg = event.respond "**Would you like to contact the staff?**\n" +
                          "Press ✅ to start the chat. The button will expire after one minute."
      msg.react '✅'
      response = Bot::BOT.add_await!(
          Discordrb::Events::ReactionAddEvent,
          emoji: '✅',
          channel: event.channel,
          timeout: 60
      )

      # If user would like to contact staff:
      if response
        # Logs time at which the chat session began in user's entry in contact hash
        # and defines array to hold chat log
        contact_data[event.user.id][:start_time] = Time.now.getgm
        contact_data[event.user.id][:messages] = Array.new

        # Creates contact channel and adds it to user's entry in contact hash
        contact_data[event.user.id][:channel] = SERVER.create_channel(
            "chat-#{event.user.name.scan(/\w|\s/).map { |c| c =~ /\s/ ? '_' : c }.join}-#{event.user.discrim}",
            topic:  "Chat with user #{event.user.mention}",
            parent: SERVER_STAFF,
            reason: "Chat with user #{event.user.distinct}"
        )

        # Sends message pinging online staff that a user would like to speak with them
        contact_data[event.user.id][:channel].send(
            "@here **User #{event.user.distinct} would like to speak with the staff.**"
        )

        # Adds event handler for messages sent in the new channel and stores it in contact hash, so it can
        # be removed later
        contact_data[event.user.id][:handler] = Bot::BOT.message in: contact_data[event.user.id][:channel] do |subevent|
          # Skips if the bot is the one sending the message or the message is the +end command
          next if subevent.user == Bot::BOT.profile ||
                  subevent.message.content == '+end'

          # If no attachments were sent with the message, sends and logs message accordingly
          if subevent.message.attachments.empty?
            event.user.dm "**#{subevent.user.distinct}** | #{subevent.message.content}"
            contact_data[event.user.id][:messages].push "#{subevent.user.distinct} - #{subevent.message.content}"

          # If attachments were sent with the message, sends and logs message accordingly
          else
            event.user.dm(
                "**#{subevent.user.distinct}:** #{subevent.message.content}\n" +
                "\n" +
                subevent.message.attachments.each_with_index.map { |a, i| "**Attachment #{i + 1}:** #{a.url}" }.join("\n")
            )
            contact_data[event.user.id][:messages].push(
                "#{subevent.user.distinct} - #{subevent.message.content}\n" +
                subevent.message.attachments.each_with_index.map { |a, i| "Attachment #{i + 1}: #{a.url}" }.join("\n")
            )
          end
        end

        # DMs user that their chat session has begun
        event.respond '**Your chat session has begun. You can speak to the staff through this DM.**'

      # If response is a timeout, deletes user entry from contact hash
      else contact_data.delete(event.user.id)
      end
    end
  end

  # Ends a chat session with a user
  command :end do |event|
    # Breaks unless the command is used in a staff contact channel
    break unless contact_data.any? { |_id, e| event.channel == e[:channel] }

    # Defines user ID and object and their entry in the contact data variable
    id, entry = contact_data.find { |_id, e| event.channel == e[:channel] }
    user = Bot::BOT.user(id)

    # DMs user that their chat session has ended
    user.dm '**Your chat session with the staff has ended.**'

    # Writes chat log to file and uploads it to log channel
    File.open("#{Bot::DATA_PATH}/log.txt", 'w') do |file|
      file.write(
          "Log of chat with user #{user.distinct} at #{entry[:start_time]}\n" +
          "\n" +
          "#{entry[:messages].join("\n--------------------\n")}\n" +
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
    Bot::BOT.remove_handler(entry[:handler])

    # Notifies staff that the chat has been logged and that the channel will be deleted in 5 seconds
    # and deletes channel accordingly
    event.respond '**The chat session has been logged. This channel will be deleted in 5 seconds.**'
    sleep 5
    entry[:channel].delete "Ended chat with #{user.distinct}"

    # Deletes user entry from contact hash
    contact_data.delete(id)

    nil # returns nil so command doesn't send a message to a nonexistent channel
  end
end