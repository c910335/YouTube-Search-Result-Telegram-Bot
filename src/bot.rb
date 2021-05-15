class Bot
  attr_reader :bot, :youtube, :subs, :results

  def self.start
    new.start
  end

  def initialize
    @youtube = YouTube.new
    @subs = {}
    @results = {}
  end

  def start
    Telegram::Bot::Client.run(Config::TELEGRAM_TOKEN) do |bot|
      @bot = bot
      set_update
      puts "Bot is running..."
      bot.listen do |msg|
        case msg
        when Telegram::Bot::Types::Message
          puts "#{msg.from.username} (#{msg.chat.id}): #{msg.text}"
          case msg.text
          when '/start'
            reply_to(msg, 'hello, world')
          when /^\/sub .+/
            query = msg.text[/^\/sub (.+)$/, 1]
            if sub(query, msg.chat.id, msg.from.username)
              reply_to(msg, "Subscribed to \"#{query}\" successfully.")
            else
              reply_to(msg, "You have already subscribed to \"#{query}\".")
            end
          when /^\/unsub .+/
            query = msg.text[/^\/unsub (.+)$/, 1]
            if playlist_id = subs[msg.chat.id][query]
              delete_playlist(playlist_id)
              reply_to(msg, "Unsubscribed to \"#{query}\" successfully.")
            else
              reply_to(msg, "Subscription not found.")
            end
          when '/list'
            if (user_subs = subs[msg.chat.id]) && !user.subs.empty?
              reply_to(msg, "You currently subscribe to\n#{user_subs.keys.join("\n")}")
            else
              reply_to(msg, "Subscription not found.")
            end
          when '/update'
            update
          end
        when Telegram::Bot::Types::CallbackQuery
          puts "#{msg.from.username} (#{msg.message.chat.id}): #{msg.data}"
          begin
            case msg.data
            when /^add \S+ .+/
              add_video(msg)
            when 'discard'
              bot.api.edit_message_text(
                chat_id: msg.message.chat.id,
                message_id: msg.message.message_id,
                text: msg.message.text,
                disable_web_page_preview: true,
                reply_markup: nil
              )
            when /^clear .+/
              query = msg.data[/^clear (.+)$/, 1]
              bot.api.send_message(
                chat_id: msg.message.chat.id,
                text: "Are you sure to clear the \"#{query}\" playlist?",
                reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [
                  Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Clear', callback_data: "force_clear #{query}"),
                  Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Cancel', callback_data: 'cancel')
                ])
              )
            when /^force_clear .+/
              query = msg.data[/^force_clear (.+)$/, 1]
              bot.api.edit_message_text(
                chat_id: msg.message.chat.id,
                message_id: msg.message.message_id,
                text: "The \"#{query}\" playlist has been cleared.",
                reply_markup: nil
              )
              subs[msg.message.chat.id][query] = youtube.clear_playlist(subs[msg.message.chat.id][query], msg.from.username, query)
            when 'cancel'
              bot.api.delete_message(chat_id: msg.message.chat.id, message_id: msg.message.message_id)
            end
          rescue Telegram::Bot::Exceptions::ResponseError => e
            puts e.message
          rescue NoMethodError
            puts e.message
          end
        end
      end
    end
  end

  def add_video(cq)
    video_id = cq.data[/^add (\S+) .+$/, 1]
    query = cq.data[/^add \S+ (.+)$/, 1]
    playlist_id = subs[cq.message.chat.id][query]
    youtube.insert_video(playlist_id, video_id)
    bot.api.edit_message_text(
      chat_id: cq.message.chat.id,
      message_id: cq.message.message_id,
      text: cq.message.text,
      disable_web_page_preview: true,
      reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Watch Playlist', url: "https://youtube.com/playlist?list=#{playlist_id}"),
        Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Clear Playlist', callback_data: "clear #{query}")
      ])
    )
  end

  def set_update
    Thread.new do
      loop do
        sleep 1200
        update
      end
    end
  end

  def update
    queries = subs.values.map(&:keys).flatten.uniq
    pre_queries = results.keys
    (pre_queries - queries).each { |query| results.delete(query) }
    queries.each do |query|
      results[query] ||= []
      result = youtube.search(query)
      result -= results[query]
      results[query] = result
    end
    notify
  end

  def notify
    subs.each_pair do |chat_id, user_subs|
      user_subs.each_key do |query|
        if result = results[query]
          result.each do |video|
            bot.api.send_message(
              chat_id: chat_id,
              text: "#{video.title}\n#{video.channel}\n#{video.url}",
              reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Interest', callback_data: "add #{video.id} #{query}"),
                Telegram::Bot::Types::InlineKeyboardButton.new(text: 'Bye', callback_data: 'discard')
              ])
            )
          end
        end
      end
    end
  end

  def sub(query, chat_id, username)
    subs[chat_id] ||= {}
    return nil if subs[chat_id][query]
    subs[chat_id][query] = youtube.new_playlist(username, query)
  end

  def reply_to(msg, text)
    bot.api.send_message(chat_id: msg.chat.id, text: text, reply_to_message_id: msg.message_id)
  end
end
