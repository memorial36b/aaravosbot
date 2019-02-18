# Crystal: Eval


# Contains a simple eval command.
module Bot::Eval
  extend Discordrb::Commands::CommandContainer
  include Constants

  # Eval command, with exception reporting
  command :eval do |event|
    # Breaks unless user is me (eval's a dangerous command)
    break unless event.user.id == MY_ID

    begin
      "**Returns: `#{eval event.message.content.sub('+eval ', '')}`**"
    rescue Exception => e
      "**Error! Message:**\n```\n#{e}```"
    end
  end
end