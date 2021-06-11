module Config
  ADMIN_CHAT_ID = 123_456_789 # The chat where the bot sends error logs.
  ADMIN_USERNAME = 'telegram_username'.freeze
  CHAT_ID_WHITELIST = Set[123_456_789, 987_654_321] # The chats allowed to use the bot (`nil` for everyone).
  SEARCH_PERIOD = 30 # minutes
  TELEGRAM_TOKEN = 'telegram_token_of_your_bot'.freeze
end
