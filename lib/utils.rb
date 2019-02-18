require 'sequel'
require 'rufus-scheduler'
ENV['TZ'] = 'GMT'

# Module containing constants that multiple crystals need access to
module Constants
  # Database object
  DB = Sequel.sqlite("#{Bot::DATA_PATH}/data.db")
  Bot::BOT.ready do
    # Server constant
    SERVER = Bot::BOT.server(466538318952267778)
  end
  # Rufus scheduler
  SCHEDULER = Rufus::Scheduler.new
  # My user ID
  MY_ID = 220509153985167360
  # Member role ID
  MEMBER_ID = 469981743584378890
  # Muted role ID
  MUTED_ID = 493821988876320768
  # Moderator role ID
  MODERATOR_ID = 469976942003748875
  # Administrator role ID
  ADMINISTRATOR_ID = 466545066924572674
end

# Methods for convenience:

# Module containing convenience methods (and companion variables/constants) that aren't instance/class methods
module Convenience
  module_function

  # Rudimentary pluralize; returns pluralized str with added 's' only if the given int is not 1
  # @param  [Integer] int the integer to test
  # @param  [String]  str the string to pluralize
  # @return [String]  singular form (i.e. 1 squid) if int is 1, plural form (8 squids) otherwise
  def plural(int, str)
    return "#{int} #{str}s" unless int == 1
    "#{int} #{str}"
  end
  alias_method(:pl, :plural)
end

# Module containing methods related to the custom help command in AaravosBot
module HelpCommand
  # Data hash for each command's help info
  @@help = Hash.new

  # Getter for help variable
  def help
    @@help
  end

  # Structures an input data hash containing a command's short blurb, a more detailed
  # description, a usage guide with arguments, the permission level needed to use the command, and
  # optionally a group to classify the command under and other aliases of the command;
  # then puts it into the @help hash with the command's name as key
  #
  # @param  data [Hash]                                       data hash containing all necessary information;
  #                                                           attributes :name, :blurb, :permission, :info, :usage required
  # @option data [Symbol]        :name                        name of the command
  # @option data [String]        :blurb                       short blurb of what the command does, used in main help command
  # @option data [Symbol]        :permission                  permission level needed to use command
  # @option data [Array<String>] :info                        more detailed info on the command; array of strings
  #                                                           for convenience, will be joined with newlines
  # @option data [Array<Array>]  :usage                       usage of the command; must be Array containing further Arrays of size 2,
  #                                                           with first element being String containing argument syntax (or nil for no arguments)
  #                                                           and second argument being String detailing what those arguments specifically do
  # @option data [Symbol]        :group      (:miscellaneous) classification that command should be grouped into
  # @option data [Array<Symbol>] :aliases                     alternative aliases for the command (Optional)
  # @return      [void]
  def command_info(data)
    unless data.class == Hash && data[:name] && data[:blurb] && data[:info] && data[:permission]
      raise ArgumentError, 'Invalid format for parameter data (must be Hash, attributes :name, :blurb, :info, :permission)'
    end
    data[:group] = :miscellaneous unless data[:group]
    if data[:usage]
      usage_lines = data[:usage].map do |usage, desc|
        if usage
          "• `+#{data[:name].to_s} #{usage}` - #{desc}"
        else
          "• `+#{data[:name].to_s}` - #{desc}"
        end
      end
    else
      usage_lines = ["• `+#{data[:name].to_s}` - No arguments needed."]
    end
    ([data[:name]] + (data[:aliases] ? data[:aliases] : [])).each do |key|
      @@help[key] = {
          group:      data[:group],
          blurb:      data[:blurb],
          info:       data[:info].join("\n"),
          usage:      usage_lines.join("\n\n"),
          permission: data[:permission],
          aliases:    data[:aliases],
      }
    end
    nil
  end
end

# YAML module from base Ruby
module YAML
  # Loads data from the YAML file at the given path, and yields the data to a block; after
  # block execution, writes the modified data to the file
  # NOTE: This only works for mutable data types; you must directly modify the block variable,
  # you cannot simply set it equal to another value!
  # @param      path [String] the path to the YAML file
  # @yieldparam data [Object] the data in the YAML file
  # @return          [void]   if a block was provided (as all processing is handled within block)
  # @return          [Object] if no block was provided; returns the data in the YAML file
  def self.load_data!(path, &block)
    data = YAML.load_file(path)
    if block_given?
      yield data
      File.open(path, 'w') { |f| YAML.dump(data, f) }
      nil
    else
      data
    end
  end
end

# Server class from discordrb
class Discordrb::Server
  # Gets a member from a given string, either user ID, user mention, distinct (username#discrim),
  # nickname, or username on the given server; options earlier in the list take precedence (i.e.
  # someone with the username GeneticallyEngineeredInklings will be retrieved over a member
  # with that as a nickname) and in the case of nicknames and usernames, it checks for the beginning
  # of the name (i.e. the full username or nickname is not required)
  # @param  str [String]            the string to match to a member
  # @return     [Discordrb::Member] the member that matches the string, as detailed above; or nil if none found
  def get_user(str)
    return self.member(str.scan(/\d/).join.to_i) if self.member(str.scan(/\d/).join.to_i)
    members = self.members
    members.find { |m| m.distinct.downcase == str.downcase } ||
    members.find { |m| str.size >= 3 && m.display_name.downcase.start_with?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.name.downcase.start_with?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.display_name.downcase.include?(str.downcase) } ||
    members.find { |m| str.size >= 3 && m.name.downcase.include?(str.downcase) }
  end
end

# Message class from discordrb
class Discordrb::Message
  # Reaction control buttons, in order
  REACTION_CONTROL_BUTTONS = ['⏮', '◀', '⏹', '▶', '⏭']

  # Reacts to the message with reaction controls. Keeps track of an index that is yielded as a parameter to the given
  # block, which is executed each time the given user presses a reaction control button. The index cannot be outside
  # the given range. Accepts an optional timeout, calculated from the last time the user pressed a reaction button.
  # Additionally accepts an optional starting index (if not provided, defaults to the start of the given range).
  # This is a blocking function -- if user presses the stop button or if the timeout expires, all reactions are
  # deleted and the thread unblocks.
  # @param [User]           user           the user who these reaction controls pertain to
  # @param [Range]          index_range    the range that the given index is allowed to be
  # @param [Integer, Float] timeout        the length, in seconds, of the timeout
  #                                        (after this many seconds the controls are deleted)
  # @param [Integer]        starting_index the initial index
  #
  # For block { |index| ... }
  # @yield                      The given block is executed every time a reaction button (other than stop) is pressed.
  # @yieldparam [Integer] index the current index
  def reaction_controls(user, index_range, timeout = nil, starting_index = index_range.first, &block)
    raise NoPermissionError, "This message wasn't sent by the current bot!" unless self.from_bot?
    raise ArgumentError, 'The starting index must be within the given range!' unless index_range.include?(starting_index)

    # Reacts to self with each reaction button
    REACTION_CONTROL_BUTTONS.each { |s| self.react_unsafe(s) }

    # Defines index variable
    index = starting_index

    # Loops until stop button is pressed or timeout has passed
    loop do
      # Defines time when the controls should expire (timeout is measured from the time of the last press)
      expiry_time = timeout ? Time.now + timeout : nil

      # Awaits reaction from user and returns response (:first, :back, :forward, :last, or nil if stopped/timed out)
      response = loop do
        await_timeout = expiry_time - Time.now
        await_event = @bot.add_await!(Discordrb::Events::ReactionAddEvent,
                                      emoji: REACTION_CONTROL_BUTTONS,
                                      channel: self.channel,
                                      timeout: await_timeout)

        break nil unless await_event
        next unless await_event.message == self &&
            await_event.user == user
        break nil if await_event.emoji.name == '⏹'
        break await_event.emoji.name
      end

      # Cases response variable and changes the index accordingly (validating that it is within the
      # given index range), yielding to the given block with the index if it is changed;
      # removes all reactions and breaks loop if response is nil
      case response
      when '⏮'
        unless index_range.first == index
          index = index_range.first
          yield index
        end
        self.delete_reaction_unsafe(user, '⏮')
      when '◀'
        if index_range.include?(index - 1)
          index -= 1
          yield index
        end
        self.delete_reaction_unsafe(user, '◀')
      when '▶'
        if index_range.include?(index + 1)
          index += 1
          yield index
        end
        self.delete_reaction_unsafe(user, '▶')
      when '⏭'
        unless index_range.last == index
          index = index_range.last
          yield index
        end
        self.delete_reaction_unsafe(user, '⏭')
      when nil
        self.delete_all_reactions_unsafe
        break
      end
    end
  end

  # Alternative to the default `Message#create_reaction` method that allows for a custom rate limit to be set;
  # unsafe, as it can be set lower to the Discord minimum of 1/0.25
  # @param [String, #to_reaction] reaction   the `Emoji` object or unicode emoji to react with
  # @param [Integer, Float]       rate_limit the length of time to set as the rate limit
  def create_reaction_unsafe(reaction, rate_limit = 0.25)
    reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
    encoded_reaction = URI.encode(reaction) unless reaction.ascii_only?
    RestClient.put(
        "#{Discordrb::API.api_base}/channels/#{self.channel.id}/messages/#{self.id}/reactions/#{encoded_reaction}/@me",
        nil, # empty payload
        Authorization: @bot.token
    )
    sleep rate_limit
  end
  alias_method :react_unsafe, :create_reaction_unsafe

  # Alternative to the default `Message#delete_reaction` method that allows for a custom rate limit to be set;
  # unsafe, as it can be set lower to the Discord minimum of 1/0.25
  # @param [User]                 user       the user whose reaction to remove
  # @param [String, #to_reaction] reaction   the `Emoji` object or unicode emoji to remove the reaction of
  # @param [Integer, Float]       rate_limit the length of time to set as the rate limit
  def delete_reaction_unsafe(user, reaction, rate_limit = 0.25)
    reaction = reaction.to_reaction if reaction.respond_to?(:to_reaction)
    encoded_reaction = URI.encode(reaction) unless reaction.ascii_only?
    RestClient.delete(
        "#{Discordrb::API.api_base}/channels/#{self.channel.id}/messages/#{self.id}/reactions/#{encoded_reaction}/#{user.id}",
        Authorization: @bot.token
    )
    sleep rate_limit
  end

  # Alternative to the default `Message#delete_all_reactions` method that allows for a custom rate limit to be set;
  # unsafe, as it can be set lower to the Discord minimum of 1/0.25
  # @param [Integer, Float] rate_limit the length of time to set as the rate limit
  def delete_all_reactions_unsafe(rate_limit = 0.25)
    RestClient.delete(
        "#{Discordrb::API.api_base}/channels/#{self.channel.id}/messages/#{self.id}/reactions",
        Authorization: @bot.token
    )
    sleep rate_limit
  end
end

# Member class from discordrb
class Discordrb::Member
  # My permission level for command usage; for testing purposes ONLY!
  @bot_owner_permission = :moderator

  # Metaclass: only used to define class accessor for bot_owner_permission variable
  # @!attribute [rw] bot_owner_permission
  class << self
    attr_accessor :bot_owner_permission
  end

  # Checks whether user has the permission level necessary to use command
  # @param  level  [Symbol]             the permission level required; must be :moderator, :administrator or :ink
  # @return        [Boolean]            whether the user has permission for the command
  def has_permission?(level)
    return self.id == 220509153985167360 if level == :ink
    my_permission = self.class.bot_owner_permission
    case level
    when :user
      true
    when :moderator
      if self.id == 220509153985167360
        my_permission == :moderator || my_permission == :administrator
      else
        self.role?(469976942003748875) || self.role?(466545066924572674)
      end
    when :administrator
      if self.id == 220509153985167360
        my_permission == :administrator
      else
        self.role?(466545066924572674)
      end
    end
  end
end

# Dataset class from Sequel
class Sequel::SQLite::Dataset
  # Updates the dataset with the conditions in `cond` to the data given in `data` if entries with the
  # conditions in `cond` exist; otherwise, inserts an entry into the dataset with the combined hash
  # of `cond` and `data`
  # @param [Hash] cond the data to query the dataset if entries exist that match it
  # @param [Hash] data the data to update the queried entries with
  def set_new(cond, data)
    if self[cond]
      self.where(cond).update(data)
    else
      self << cond.merge(data)
    end
    nil
  end
end