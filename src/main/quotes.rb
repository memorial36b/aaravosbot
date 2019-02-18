# Crystal: Quotes


# This crystal handles the storybook functionality; when a message receives enough 📷 reacts, it will be "quoted"
# in an embed in the #aaravos_storybook channel.
module Bot::Quotes
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Quoted messages dataset
  QUOTED_MESSAGES = DB[:quoted_messages]
  # #aaravos_storybook ID
  STORYBOOK_ID = 506866876417048586

  qb_cams = 6

  # Sets cameras needed to quote message
  command :asbcams do |event, arg = 6|
    # Breaks unless user is moderator
    break unless event.user.has_permission?(:moderator)

    # Sets cams needed to quote and responds to command
    qb_cams = arg.to_i
    event << "**Set number of camera reactions required to quote a message to #{arg.to_i}.**"
  end

  # Detects when messages have reached the required number of cameras to be quoted
  reaction_add(emoji: '📷') do |event|
    # Skips unless the message has exactly the number of cameras to be quoted
    next unless event.message.reactions[[0x1F4F7].pack('U*')].count == qb_cams

    # Skips if message has already been quoted
    next if QUOTED_MESSAGES[id: event.message.id]

    # Sends embed to #aaravos_storybook with a quote of the message
    Bot::BOT.channel(STORYBOOK_ID).send_embed do |embed|
      embed.author = {
          name: "#{event.message.author.on(SERVER).display_name} (#{event.message.author.distinct})",
          icon_url: event.message.author.avatar_url
      }
      embed.color = 0xFFD700
      embed.description = event.message.content
      embed.image = Discordrb::Webhooks::EmbedImage.new(url: event.message.attachments[0].url) unless event.message.attachments == []
      embed.timestamp = event.message.timestamp.getgm
      embed.footer = {text: "##{event.message.channel.name}"}
    end

    # Adds message entry to database
    QUOTED_MESSAGES << {
        channel_id: event.channel.id,
        id:         event.message.id
    }

    # Deletes all reactions on message to prevent cam abuse
    event.message.delete_all_reactions
  end

  # Help command info for every command in this crystal
  module HelpInfo
    extend HelpCommand

    # +asbcams
    command_info(
        name: :asbcams,
        blurb: 'Sets cameras needed for a quote.',
        permission: :moderator,
        info: ['Sets the number of cameras required to quote a message in <#506866876417048586>.'],
        usage: [['<number>', 'Sets the number of cameras required to quote to the specified value. Defaults to 5.']]
    )
  end
end