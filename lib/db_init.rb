# This script initializes the dataset tables required by different commands of the bot.
# It can also function as a schema for the structure of each table.
require 'sequel'

# Encapsulates all database initialization functionality into module so constants aren't thrown into global scope
module DatabaseInit
  # Database object
  DB = Sequel.sqlite("#{Bot::DATA_PATH}/data.db")

  # Assignable roles dataset
  DB.create_table? :assignable_roles do
    String  :key   # Role key, or command
    Integer :id    # Role ID
    String  :group # Group the role is in
    String  :desc  # Role's description
  end

  # Birthdays dataset
  DB.create_table? :birthdays do
    Integer :id       # User's ID
    String  :birthday # User's birthday, in format MM/DD
  end

  # Birthday messages dataset
  DB.create_table? :birthday_messages do
    Integer :channel_id # Message's channel ID
    Integer :id         # Message ID
  end

  # Hug stats dataset
  DB.create_table? :hug_stats do
    Integer :id       # User's ID
    Integer :given    # Hugs user has given
    Integer :received # Hugs user has received
  end

  # Tart stats dataset
  DB.create_table? :tart_stats do
    Integer :id       # User's ID
    Integer :given    # Tarts user has given
    Integer :received # Tarts user has received
  end

  # Muted (users) dataset
  DB.create_table? :muted do
    Integer :id       # User's ID
    Integer :end_time # Time that user's mute ends, as a Unix timestamp
  end

  # Quoted messages dataset
  DB.create_table? :quoted_messages do
    Integer :channel_id # Message's channel ID
    Integer :id         # Message ID
  end

  # Staff chat session info dataset
  DB.create_table? :chat_info do
    Integer :user_id    # ID of user contacting staff
    Integer :channel_id # ID of the staff contact channel
    Integer :start_time # Time that the chat began, as a Unix timestamp

  end

  # Staff chat session's message log dataset
  DB.create_table? :chat_message_log do
    Integer :user_id   # ID of the user whose contact session a message is from
    String  :message   # A formatted string of the sent message, with the author's full username at the front
    Integer :timestamp # Time that the message was sent, as a Unix timestamp
  end
end