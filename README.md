# YouTube Search Result Telegram Bot

A Telegram bot that collects search results on YouTube.

## Installation

1. Clone this repository.

```sh
git clone https://github.com/c910335/YouTube-Search-Result-Telegram-Bot.git
cd YouTube-Search-Result-Telegram-Bot
```

2. Install the dependencies.

```sh
bundle install
```

3. Edit the configuration file.

```sh
cp config.sample.rb config.rb
vim config.rb
```

4. Download your `client_secrets.json` file from Google Cloud Platform.

```sh
cp ~/Downloads/your_client_secrets.json client_secrets.json
```

## Usage

1. Run the bot.

```sh
ruby main.rb
```

2. Talk to the bot on Telegram with these commands.

- `/start`: Say hello
- `/sub`: Subscribe to the search results of a keyword
- `/unsub`: Unsubscribe to a keyword
- `/list`: List your subscriptions

## Contributing

1. Fork it (<https://github.com/c910335/YouTube-Search-Result-Telegram-Bot/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Tatsujin Chin](https://github.com/c910335) - creator and maintainer
