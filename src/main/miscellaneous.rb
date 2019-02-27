# Crystal: Miscellaneous


# This crystal adds miscellaneous features that may, for various reasons, not need a full crystal.
module Bot::Miscellaneous
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # AaravosMusic ID
  AARAVOS_MUSIC_ID = 509544850085904384
  # IDs of voice channels with their respective text channels {voice => text}
  VOICE_TEXT_CHATS = {
    466538319585476611 => 492864853401141259, # Music
    507552578511568907 => 507553012663975956, # General
    546892277075935252 => 546892450086649857, # Gaming
    547124486160252995 => 547124486160252995  # Radio Show
  }

  # Detects when a user has joined, moved or left a voice channel, and updates
  # voice text channel visibility accordingly
  voice_state_update do |event|
    # Skips if user is AaravosMusic or event channel is the same as old channel
    # (user is just changing their mute/deafen state)
    next if event.user.id == AARAVOS_MUSIC_ID ||
            event.channel == event.old_channel

    # Deletes user's overwrites in each of the voice text channels
    VOICE_TEXT_CHATS.values.each { |id| Bot::BOT.channel(id).delete_overwrite(event.user.id) }

    # If user has joined a voice channel that has a corresponding text channel, defines
    # overwrite for its text channel and responds to user
    if event.channel && VOICE_TEXT_CHATS[event.channel.id]
      text_channel = Bot::BOT.channel(VOICE_TEXT_CHATS[event.channel.id])
      text_channel.define_overwrite(event.user, 1024, 0)
      text_channel.send_temporary_message(
          "**#{event.user.mention}, welcome to #{text_channel.mention}.**\n" +
          "This is the text chat for the voice channel you're connected to.",
          10 # seconds to delete
      )
    end
  end

  # Clean command for #music channel; not indexed in +help because it is technically part of music module
  command(:clean, channels: %w(#dragon-dj)) do |event, arg = '40'|
    # Breaks unless the given number of messages is within 2 and 100
    break unless (2..100).include?(arg.to_i)

    messages = event.channel.history(arg.to_i).select { |m| m.author.id == AARAVOS_MUSIC_ID || m.content[0] == '+' }

    # Cases the message count, as the Channel#delete_messages method does not support deletion of a single message
    case messages.size
    when 2..100 then event.channel.delete_messages(messages)
    when 1 then messages[0].delete
    end

    # Responds to user
    event.channel.send_temp(
        "Searched **#{arg.to_i}** messages and cleaned up **#{messages.size}** music commands and responses.",
        5 # seconds to delete
    )
  end
end