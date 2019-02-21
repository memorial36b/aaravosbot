# Crystal: Fun
require 'yaml'

# This crystal has random fun commands.
module Bot::Fun
  extend Discordrb::Commands::CommandContainer
  extend Convenience
  include Constants

  # Hug stats dataset
  HUG_STATS = DB[:hug_stats]
  # Tart stats dataset
  TART_STATS = DB[:tart_stats]
  # List of ban scenarios
  BAN_SCENARIOS = [
      "{user} has been used as a dark magic source.",
      "{user} has been CRUSHED by the ban hammer.",
      "{user} has been coined.",
      "Oopsie, {user} did a Runaan.",
      "The moonshadow elves got {user}.",
      "{user} attacked Jade’s braincells. They have been eliminated in Brawlhalla.",
      "{user} has been banished to atone for their crimes in <#506866876417048586>.",
      "{user} has been phased out of reality by bad photo quality. Mage’s Potato got them.",
      "{user} is now lost in the secret ban message.",
      "{user} has gotten lost in the airport.",
      "{user} was sent on an FTA paid trip to hell. Please enjoy the plane.",
      "{user} became the midseason. They no longer exist.",
      "{user} climbed the ka-tallest mountain but tripped and fell down to the bottom.",
      "{user} found a secret door... but not the secret exit.",
      "{user} became the fluffiest pancake.",
      "{user} has been locked into the dungeon. His feedback has been a gift.",
      "{user} got consumed by the OwOs. I blame Virsters.",
      "{user} doesn’t believe in locks... what a bad time to be delusional.",
      "{user} got murdered.",
      "{user} was found by locks.",
      "{user} didn’t get a storm in time.",
      "{user} saw Bait’s naughty side.",
      "{user} saw Bait’s naughty side and is still recovering.",
      "{user} saw Bait’s naughty side. They are no longer with us.",
      "{user} ate Jade’s last brain cell. No punishment is given.",
      "{user} beat lorebot at lore. This is the coverup.",
      "{user} talked with Amman for an hour. They have ascended beyond the server.",
      "{user} put on some Sunforged Armor. They are now hardboiled.",
      "Aaravos didn’t like {user}. The hit squad has already arrived.",
      "Omae wa mou shindeiru.\n{user}: NANI?",
      "{user} tried to rebel. it didn’t work out.",
      "{user} saw into the mod chat. They left.",
      "{user} saw Bait's gallery. They're unsure what to do.",
      "{user} has been found dead in Miami.",
      "{user} saw LoreBoy’s™ conspiracy board. Their mind is recovering.",
      "{user} has been found dead in Katolis.",
      "{user} sent memes so spicy, it burnt them.",
      "{user} was too straight.",
      "{user} tried to find Jade's last brain cell, they're still searching.",
      "{user} has been found dead in Xadia.",
      "{user} has been killed with weapons grade bread.",
      "{user} found murdered by the Virsters.",
      "{user} had to leave due to being habsolutely hurious.",
      "{user} doesn't feel so good....",
      "{user}...... :(",
      "{user} has drowned in the pool of ban messages.",
      "{user} attempted to fool the court. Now there is no fool. Just a skeleton.",
      "{user} insulted a cephalopod. They were splatted and squidbagged upon."
  ]
  # List of genders; all of them are valid and should be accepted
  GENDER_OPTIONS = [
    ["genderqueer", "twink", "motherfucking", "bisexual", "dumbass", "hhhhhh", "nerdy", "ugly", "disastrous", "furry", "sparkly", "tired", "loser", "weeb", "gay", "idiot", "dramatic", "queer", "lazy", "trans", "edgy", "nonbinary", "bigender", "chaotic", "stupid", "moronic", "shitty", "slutty", "genderfluid", "immortal", "cute", "sweet", "monstrous", "eldritch", "alien", "horny", "thirsty", "ghostly", "satanic", "royal", "poor", "high", "robotic", "cyborg", "dragon", "ninja", "hungry", "angry", "hangry", "habsolutely hurious", "fucking"],
    ["genderqueer", "twink", "motherfucking", "bisexual", "dumbass", "hhhhhh", "nerdy", "ugly", "disastrous", "furry", "sparkly", "tired", "loser", "weeb", "gay", "idiot", "dramatic", "queer", "lazy", "trans", "edgy", "nonbinary", "bigender", "chaotic", "stupid", "moronic", "shitty", "slutty", "genderfluid", "immortal", "cute", "sweet", "monstrous", "eldritch", "alien", "horny", "thirsty", "ghostly", "satanic", "royal", "poor", "high", "robotic", "cyborg", "dragon", "ninja", "hungry", "angry", "hangry", "fucking", "ass", "gamer", "???", "nerd", "[REDACTED]", "vampire", "bitch", "werewolf", "demon", "goblin", "gremlin", "imp", "faerie", "monster", "nymph", "humbug", "squid", "octopus", "ghost", "robot", "elf", "mage", "jedi", "artist", "musician", "writer", "snake", "angel", "orc", "baby", "droid", "minion"],
    ["twink", "bisexual", "dumbass", "furry", "loser", "weeb", "gay", "idiot", "queer", "trans", "nonbinary", "bigender", "genderfluid", "immortal", "alien", "royal", "cyborg", "dragon", "ninja", "boyfriend", "ass", "gamer", "nerd", "disaster", "person", "fuck", "woman", "girlfriend", "[REDACTED]", "moron", "vampire", "bitch", "motherfucker", "werewolf", "demon", "goblin", "gremlin", "imp", "faerie", "monster", "nymph", "eldritch being", "humbug", "squid", "octopus", "ghost", "satan", "robot", "elf", "mage", "jedi", "artist", "musician", "writer", "snake", "default dancer", "angel", "orc", "baby", "droid", "minion", "duolingo owl", "kirby", "toddler"]
  ]
  # Bucket for the genderator
  GENDERATOR_BUCKET = Bot::BOT.bucket(
      :genderator,
      limit:     1,
      time_span: 10
  )
  # Bucket for hugging and jellytart
  HUG_TART_BUCKET = Bot::BOT.bucket(
      :hug_tart,
      limit:     1,
      time_span: 3
  )

  # Genderator
  command :genderator do |event|
    # If the rate limit has been hit, respond to user and break
    if (time = GENDERATOR_BUCKET.rate_limited?(event.user.id))
      event.channel.send_temp("Please wait **#{pl(time.round, 'second')}**.", 3)
      break
    end

    # Responds to user with their 100% accurate gender
    event << "**Your gender is:** `#{GENDER_OPTIONS.map(&:sample).join(' ')}`"
  end

  command :jellytart, aliases: [:tart] do |event, *args|
    # Breaks unless user is valid and not the event user
    break unless (user = SERVER.get_user(args.join(' '))) &&
                 user != event.user

    # If the rate limit has been hit, respond to user and break
    if (time = HUG_TART_BUCKET.rate_limited?(event.user.id))
      event.send_temp("Please wait **#{pl(time.round, 'second')}**.", 3)
      break
    end

    # Adds one to/defines entry for event user's total hugs given and hugged user's total received in the database
    if (entry = TART_STATS[id: event.user.id])
      TART_STATS.where(entry).update(given: entry[:given] + 1)
    else
      TART_STATS << {
          id:       event.user.id,
          given:    1,
          received: 0
      }
    end
    if (entry = TART_STATS[id: user.id])
      TART_STATS.where(entry).update(received: entry[:received] + 1)
    else
      TART_STATS << {
          id:       user.id,
          given:    0,
          received: 1
      }
    end

    # Responds to user
    event.respond(
      "<:tdpTartgasm:492743401616310272> | **#{event.user.name}** *has given* #{user.mention} *a jelly tart!*",
      false, # tts
      {
        author: {
          name: "#{pl(TART_STATS[id: event.user.id][:given], 'tart')} given | #{pl(TART_STATS[id: event.user.id][:received], 'tart')} received",
          icon_url: event.user.avatar_url
        },
        color: 0xFFD700
      }
    )
  end

  command :hug do |event, *args|
    # Breaks unless user is valid and not the event user
    break unless (user = SERVER.get_user(args.join(' '))) &&
                 user != event.user

    # If the rate limit has been hit, respond to user and break
    if (time = HUG_TART_BUCKET.rate_limited?(event.user.id))
      event.send_temp("Please wait **#{pl(time.round, 'second')}**.", 3)
      break
    end

    # Adds one to/defines entry for event user's total hugs given and hugged user's total received in the database
    if (entry = HUG_STATS[id: event.user.id])
      HUG_STATS.where(entry).update(given: entry[:given] + 1)
    else
      HUG_STATS << {
          id:       event.user.id,
          given:    1,
          received: 0
      }
    end
    if (entry = HUG_STATS[id: user.id])
      HUG_STATS.where(entry).update(received: entry[:received] + 1)
    else
      HUG_STATS << {
          id:       user.id,
          given:    0,
          received: 1
      }
    end

    # Responds to user
    event.respond(
      ":hugging: | **#{event.user.name}** *gives* #{user.mention} *a warm hug.*",
      false, # tts
      {
        author: {
          name: "#{pl(HUG_STATS[id: event.user.id][:given], 'hug')} given - #{pl(HUG_STATS[id: event.user.id][:received], 'hug')} received",
          icon_url: event.user.avatar_url
        },
        color: 0xFFD700
      }
    )
  end

  # Fake bans a user
  command :ban do |event, *args|
    # Breaks unless given user is valid
    break unless (user = SERVER.get_user(args.join(' ')))

    # Responds to command with a ban scenario
    "*#{BAN_SCENARIOS.sample.gsub('{user}', user.mention)}*"
  end

  # Help command info for every command in this crystal
  module HelpInfo
    extend HelpCommand

    # +genderator
    command_info(
        name: :genderator,
        blurb: "What's your gender?",
        permission: :user,
        group: :fun,
        info: ["Carefully scans and analyzes the user's brainwaves through revolutionary technology and intelligently predicts what their gender is."]
    )

    # +jellytart
    command_info(
        name: :jellytart,
        blurb: 'Gives a jelly tart to someone.',
        permission: :user,
        info: ['Gives a jelly tart to a user of your choice. <:tdpTartgasm:492743401616310272>'],
        usage: [['<user>', 'Gives a jelly tart to a user. Accepts IDs, usernames, nicknames and mentions.']],
        group: :fun,
        aliases: [:tart]
    )

    # +hug
    command_info(
        name: :hug,
        blurb: 'Gives a hug to someone.',
        permission: :user,
        info: ['Someone in need of support, or just want to show them you care? This command sends them a warm virtual hug.'],
        usage: [['<user>', 'Sends a hug to a user. Accepts IDs, usernames, nicknames and mentions.']],
        group: :fun
    )

    # +ban
    command_info(
        name: :ban,
        blurb: '"Bans" a user',
        permission: :user,
        info: ['"Bans" a user by putting the user through a fake ban scenario.'],
        usage: [['<user>', '"Bans" the given user.']],
        group: :fun
    )
  end
end