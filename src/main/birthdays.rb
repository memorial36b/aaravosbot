# Crystal: Birthdays


# This crystal handles users setting their birthdays, and the automatic giving
# of the birthday role and birthday announcements.
module Bot::Birthdays
  extend Discordrb::Commands::CommandContainer
  extend Discordrb::EventContainer
  include Constants

  # Birthdays dataset
  BIRTHDAYS = DB[:birthdays]
  # Birthday messages dataset
  BIRTHDAY_MESSAGES = DB[:birthday_messages]
  # Birthday role ID
  BIRTHDAY_ID = 533760328241250335
  # #greneral ID
  GENERAL_ID = 466538319585476609

  # Validates the given string as a correct date, returning the month and day integers if it is valid
  # @param  [String]              str the string to be validated, of the format mm/dd
  # @return [Array<Integer>, nil]     the month and day integers, or nil if date is invalid
  def self.vali_date(str)
    # Define month and day variables
    month, day = str.split('/').map(&:to_i)

    # Case month variable and return month and day if they are valid
    case month
    when 2 # February (28 days)
      return month, day if (1..28).include? day
    when 4, 6, 9, 11 # April, June, September, November (30 days)
      return month, day if (1..30).include? day
    when 1, 3, 5, 7, 8, 10, 12 # January, March, May, July, August, October, December (31 days)
      return month, day if (1..31).include? day
    end

    # Return nil otherwise
    nil
  end

  # Master birthday command: sets a user's birthday (normal users can set their own, staff can set anyone's),
  # gets a user's birthday, checks what the next birthday is or deletes a birthday
  command :birthday do |event, *args|
    # Sets argument default to 'check'
    args[0] ||= 'check'

    # If user wants to set birthday, the birthday is given and the date format is valid:
    if args[0].downcase == 'set' &&
       args.size >= 2 && # ensures birthday is given
       (date_array = vali_date(args[1])) # ensures birthday is valid
      # If user is a moderator setting another user's birthday and user is valid:
      if args.size >= 3 &&
         event.user.has_permission?(:moderator) &&
         (user = SERVER.get_user(args[2..-1].join(' ')))

        # Defines/updates user entry in database with the new birthday
        BIRTHDAYS.set_new(
            {id:       user.id},
             birthday: date_array.join('/')
        )

        # Responds to user
        event << "This user's birthday has been set as **#{Time.new(*[2000] + date_array).strftime('%B %-d')}**."

      # If user is setting their own birthday:
      elsif args.size == 2
        # Defines/updates user entry in database with the new birthday
        BIRTHDAYS.set_new(
            {id:       event.user.id},
             birthday: date_array.join('/')
        )

        # Responds to user
        event << "#{event.user.mention}, your birthday has been set as **#{Time.new(*[2000] + date_array).strftime('%B %-d')}**."
      end

    # If user is checking a birthday:
    elsif args.size >= 1 &&
          args[0].downcase == 'check'
      # Defines user variable based on whether user wants to check their own birthday or another user's, and
      # breaks if the user is invalid in case of the latter
      if args.size == 1
        user = event.user
      elsif args.size >= 2 &&
            (user = SERVER.get_user(args[1..-1].join(' ')))
      else break
      end

      # If user has an entry in the database, responds with embed containing the info
      if (entry = BIRTHDAYS[id: user.id])
        event.send_embed do |embed|
          embed.author = {
              name: "USER: #{user.display_name} (#{user.distinct})",
              icon_url: user.avatar_url
          }
          embed.description = "#{user.mention}'s birthday is **#{Time.new(*[2000] + vali_date(entry[:birthday])).strftime('%B %-d')}**."
          embed.color = 0xFFD700
        end

      # Otherwise, respond to user
      else event.send_temp('This user has not set their birthday.', 5)
      end

    # If user is checking the next birthday:
    elsif args[0].downcase == 'next'
      upcoming_birthdays = BIRTHDAYS.map([:id, :birthday]).map do |id, birthday|
        if Time.utc(*[Time.now.year] + vali_date(birthday)) > Time.now.getgm
          [id, Time.utc(*[Time.now.year] + vali_date(birthday))]
        else
          [id, Time.utc(*[Time.now.year + 1] + vali_date(birthday))]
        end
      end
      upcoming_birthdays.sort_by! { |_id, t| t }
      next_date = upcoming_birthdays[0][1]
      next_users = upcoming_birthdays.select { |_id, t| t == next_date }.map { |id, _t| id }

      # Responds with embed containing the upcoming birthdays
      event.send_embed do |embed|
        embed.author = {
            name: 'Birthdays: Next',
            icon_url: 'https://cdn.discordapp.com/attachments/330586271116165120/427435169826471936/glossaryck_icon.png'
        }
        embed.description = "**On #{next_date.strftime('%B %-d')}:**\n" +
                             next_users.reduce('') do |memo, id| # combines IDs into parsed string of usernames
                               next memo unless (user = SERVER.member(id))
                               memo + "\n**• #{user.display_name} (#{user.distinct})**"
                             end
        embed.color = 0xFFD700
      end

    # If user wants to delete a birthday, is a moderator, given user is valid and has an entry in the birthday
    # file, delete the birthday and respond to user
    elsif args[0].downcase == 'delete' &&
          event.user.has_permission?(:moderator) &&
          (user = SERVER.get_user(args[1..-1].join(' '))) &&
          (entry = BIRTHDAYS[id: user.id])
      BIRTHDAYS.where(entry).delete
      event << "This user's birthday has been deleted."
    end
  end

  # Cron job that announces birthdays 5 minutes after midnight in GMT
  SCHEDULER.cron '5 0 * * *' do
    # Unpins old birthday messages, deletes them from the database and remove old birthday roles
    BIRTHDAY_MESSAGES.all { |e| Bot::BOT.channel(e[:channel_id]).load_message(e[:id]).delete }
    BIRTHDAY_MESSAGES.delete
    SERVER.role(BIRTHDAY_ID).members.each { |m| m.remove_role(BIRTHDAY_ID) }

    # Iterates through all users who have a birthday today:
    BIRTHDAY_MESSAGES.all.select { |id, d| [Time.now.month, Time.now.day] == vali_date(d) }.each do |id, d|
      # Skips unless user is present within server
      next unless (user = SERVER.member(id))

      # Gives user birthday role, sends and pins birthday message
      user.add_role(BIRTHDAY_ID)
      msg = Bot::BOT.channel(GENERAL_ID).send "**Happy Birthday, #{user.mention}!**"
      msg.pin

      # Stores message and channel ID in database
      BIRTHDAY_MESSAGES << {
          channel_id: GENERAL_ID,
          id:         msg.id
      }
    end
  end

  # Deletes user from birthday data file if they leave
  member_leave do |event|
    BIRTHDAY_MESSAGES.where(id: event.user.id).delete
  end

  # Help command info for every command in this crystal
  module HelpInfo
    extend HelpCommand

    # +birthday
    command_info(
        name: :birthday,
        blurb: 'Master birthday command.',
        permission: :user,
        info: [
            'Allows you to set your birthday, check what your birthday is set to or check the next birthday,',
            'Birthdays are announced in <#466538319585476609> 5 minutes after midnight GMT!'
        ],
        usage: [
            ['check', 'Returns what your own birthday is set to. This is the default with no arguments.'],
            ['check <user>', 'Returns the birthday of another user.'],
            ['set mm/dd', 'Sets your birthday.'],
            ['next', 'Returns whose birthday is the next to come, and what day it is.'],
            ['set mm/dd <user>', '(Staff only) Sets the birthday of another user.'],
            ['delete <user>', '(Staff only) Deletes the birthday of a user.'],
        ]
    )
  end
end