class Bot
  attr_reader :bot, :youtube, :subs, :pre_results, :new_results, :last_time, :blocks

  def self.start
    new.start
  end

  def initialize
    @youtube = YouTube.new
    @subs = {}
    @blocks = {}
    if File.exist?('subscriptions.json')
      restore
    else
      @pre_results = {}
      @last_time = DateTime.now
    end
    @new_results = {}
  end

  def start
    Telegram::Bot::Client.run(Config::TELEGRAM_TOKEN) do |bot|
      @bot = bot
      set_update
      log 'Bot started.'
      begin
        bot.listen do |msg|
          log msg
          case msg
          when Telegram::Bot::Types::Message
            case msg.text
            when '/start'
              reply_to(msg, 'hello, world')
            when '/sub'
              reply_to(msg, 'Please enter the keyword you would like to subscribe.',
                       reply_markup: Telegram::Bot::Types::ForceReply.new(force_reply: true))
            when '/unsub'
              reply_to(msg, 'Please enter the keyword you would like to unsubscribe.',
                       reply_markup: Telegram::Bot::Types::ForceReply.new(force_reply: true))
            when '/list'
              if (user_subs = subs[msg.chat.id]) && !user_subs.empty?
                reply_to(msg, "You are subscribing to\n#{user_subs.keys.join("\n")}")
              else
                reply_to(msg, 'Subscription not found.')
              end
            when '/block'
              reply_to(msg, 'Please enter the channel id you would like to block.',
                       reply_markup: Telegram::Bot::Types::ForceReply.new(force_reply: true))
            when '/unblock'
              reply_to(msg, 'Please enter the channel id you would like to unblock.',
                       reply_markup: Telegram::Bot::Types::ForceReply.new(force_reply: true))
            when '/blocks'
              if (user_blocks = blocks[msg.chat.id]) && !user_blocks.empty?
                reply_to(msg, "You are blocking\n#{user_blocks.to_a.join("\n")}")
              else
                reply_to(msg, "You aren't blocking any channel.")
              end
            when '/update'
              update(clear: false)
            else
              if replied = msg.reply_to_message
                case replied.text
                when 'Please enter the keyword you would like to subscribe.'
                  if sub(msg.text, msg.chat.id, msg.from.username)
                    reply_to(msg, "Subscribed to \"#{msg.text}\" successfully.")
                  else
                    reply_to(msg, "You have already subscribed to \"#{msg.text}\".")
                  end
                when 'Please enter the keyword you would like to unsubscribe.'
                  if unsub(msg.text, msg.chat.id)
                    reply_to(msg, "Unsubscribed to \"#{msg.text}\" successfully.")
                  else
                    reply_to(msg, 'Subscription not found.')
                  end
                when 'Please enter the channel id you would like to block.'
                  if block(msg.text, msg.chat.id)
                    reply_to(msg, "The channel \"#{msg.text}\" has been blocked.")
                  else
                    reply_to(msg, 'You have already blocked the channel.')
                  end
                when 'Please enter the channel id you would like to unblock.'
                  if unblock(msg.text, msg.chat.id)
                    reply_to(msg, "The channel \"#{msg.text}\" has been unblocked.")
                  else
                    reply_to(msg, 'Channel not found.')
                  end
                end
              end
            end
          when Telegram::Bot::Types::CallbackQuery
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
                  reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
                    inline_keyboard: [[
                      Telegram::Bot::Types::InlineKeyboardButton.new(
                        text: 'Clear', callback_data: "force_clear #{query}"
                      ),
                      Telegram::Bot::Types::InlineKeyboardButton.new(
                        text: 'No', callback_data: 'no_clear'
                      )
                    ]]
                  )
                )
              when /^force_clear .+/
                query = msg.data[/^force_clear (.+)$/, 1]
                bot.api.edit_message_text(
                  chat_id: msg.message.chat.id,
                  message_id: msg.message.message_id,
                  text: "The \"#{query}\" playlist has been cleared.",
                  reply_markup: nil
                )
                subs[msg.message.chat.id][query] =
                  youtube.clear_playlist(subs[msg.message.chat.id][query], msg.from.username, query)
                save
              when 'no_clear'
                bot.api.delete_message(chat_id: msg.message.chat.id, message_id: msg.message.message_id)
              end
              bot.api.answer_callback_query(callback_query_id: msg.id)
            rescue Telegram::Bot::Exceptions::ResponseError, NoMethodError, Signet::AuthorizationError => e
              log e
            end
          end
        end
      rescue Faraday::ConnectionFailed => e
        log e
        retry
      end
    end
  end

  def add_video(cq)
    video_id = cq.data[/^add (\S+) .+$/, 1]
    query = cq.data[/^add \S+ (.+)$/, 1]
    playlist_id = subs[cq.message.chat.id][query]
    if youtube.insert_video(playlist_id, video_id)
      bot.api.edit_message_text(
        chat_id: cq.message.chat.id,
        message_id: cq.message.message_id,
        text: cq.message.text,
        disable_web_page_preview: true,
        reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
          inline_keyboard: [[
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text: 'Watch Playlist', url: "https://youtube.com/playlist?list=#{playlist_id}"
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
              text: 'Clear Playlist', callback_data: "clear #{query}"
            )
          ]]
        )
      )
    else
      bot.api.edit_message_text(
        chat_id: cq.message.chat.id,
        message_id: cq.message.message_id,
        text: 'The video has been removed.',
        reply_markup: nil
      )
    end
  end

  def set_update
    Thread.new do
      loop do
        sleep 30
        next unless DateTime.now >= last_time + Config::SEARCH_PERIOD.minutes

        begin
          update
        rescue e
          log e
        end
      end
    end
  end

  def update(clear: true)
    log 'Searching for new videos.'
    queries = subs.values.map(&:keys).flatten.uniq
    @pre_results = new_results if clear
    @new_results = {}
    queries.each do |query|
      result = youtube.search(query, last_time - 1.minutes)
      result -= pre_results[query] if pre_results.include?(query)
      new_results[query] = result
      unless result.empty?
        log "Found #{result.size} video#{result.size > 1 ? 's' : ''} for \"#{query}\"."
      end
    end
    @last_time = DateTime.now
    new_results.each_pair do |query, result|
      pre_results[query] ||= []
      pre_results[query] |= result
    end
    save
    notify
  end

  def notify
    subs.each_pair do |chat_id, user_subs|
      user_subs.each_key do |query|
        next unless result = new_results[query]

        user_blocks = blocks[chat_id]
        result.each do |video|
          next if user_blocks.include? video.channel_id

          bot.api.send_message(
            chat_id: chat_id,
            text: "#{video.title}\n#{video.duration}\n#{video.channel_title} (#{video.channel_id})\n#{video.url}",
            reply_markup: Telegram::Bot::Types::InlineKeyboardMarkup.new(
              inline_keyboard: [[
                Telegram::Bot::Types::InlineKeyboardButton.new(
                  text: 'Interest', callback_data: "add #{video.id} #{query}"
                ),
                Telegram::Bot::Types::InlineKeyboardButton.new(
                  text: 'Bye', callback_data: 'discard'
                )
              ]]
            )
          )
        end
      end
    end
  end

  def sub(query, chat_id, username)
    subs[chat_id] ||= {}
    return false if subs[chat_id][query]

    subs[chat_id][query] = youtube.new_playlist(username, query)
    save
    true
  end

  def unsub(query, chat_id)
    subs[chat_id] ||= {}
    return false unless playlist_id = subs[chat_id][query]

    youtube.delete_playlist(playlist_id)
    subs[chat_id].delete(query)
    save
    true
  end

  def block(channel_id, chat_id)
    blocks[chat_id] ||= Set.new
    return false if blocks[chat_id].include?(channel_id)

    blocks[chat_id].add(channel_id)
    save
    true
  end

  def unblock(channel_id, chat_id)
    blocks[chat_id] ||= {}
    return false unless blocks[chat_id].include?(channel_id)

    blocks[chat_id].delete(channel_id)
    save
    true
  end

  def save
    File.open('subscriptions.json', 'w') do |file|
      JSON.dump(
        {
          subs: subs,
          pre_results: pre_results,
          last_time: last_time,
          blocks: blocks
        }, file
      )
    end
  end

  def restore
    restored = JSON.parse(File.read('subscriptions.json'))
    restored['subs'].each_pair do |id, user_subs|
      subs[id.to_i] = user_subs
    end
    @pre_results = restored['pre_results']
    pre_results.each_value do |r|
      r.map! do |v|
        YouTube::Video.new(v['id'], v['title'], v['channel_id'], v['channel_title'], v['duration'])
      end
    end
    @last_time = DateTime.parse(restored['last_time'])
    restored['blocks'].each_pair do |id, user_blocks|
      blocks[id.to_i] = Set.new(user_blocks)
    end
  end

  def log(obj)
    case obj
    when Telegram::Bot::Types::Message
      puts "(M@#{obj.chat.id}) #{obj.from.username}: #{obj.text} [#{Time.now.strftime('%H:%M')}]"
    when Telegram::Bot::Types::CallbackQuery
      puts "(C@#{obj.message.chat.id}) #{obj.from.username}: #{obj.data} [#{Time.now.strftime('%H:%M')}]"
    when Exception
      puts obj.full_message
      begin
        bot.api.send_message(chat_id: Config::ADMIN_CHAT_ID, text: obj.full_message)
      rescue StandardError => e
        puts e.full_message
      end
    else
      puts "#{obj} [#{Time.now.strftime('%H:%M')}]"
    end
  end

  def reply_to(msg, text, **options)
    bot.api.send_message(chat_id: msg.chat.id, text: text, reply_to_message_id: msg.message_id, **options)
  end
end
