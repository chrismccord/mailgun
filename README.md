# Elixir Mailgun Client [![Build Status](https://travis-ci.org/chrismccord/mailgun.svg)](https://travis-ci.org/chrismccord/mailgun)


```elixir
# config/config.exs

config :my_app, mailgun_domain: "https://api.mailgun.net/v3/mydomain.com",
                mailgun_key: "key-##############"


# lib/mailer.ex
defmodule MyApp.Mailer do
  use Mailgun.Client, domain: Application.get_env(:my_app, :mailgun_domain),
                      key: Application.get_env(:my_app, :mailgun_key)

  @from "info@example.com"

  def send_welcome_text_email(user) do
    send_email to: user.email,
               from: @from,
               subject: "hello!",
               text: "Welcome!"
  end

  def send_welcome_html_email(user) do
    send_email to: user.email,
               from: @from,
               subject: "hello!",
               html: "<strong>Welcome!</strong>"
  end
end


iex> MyApp.Mailer.send_welcome_text_email(user)
{:ok, ...}
```

### Installation

Add mailgun to your `mix.exs` dependencies:

  ```elixir
  def deps do
    [ {:mailgun, "~> 0.1.1"} ]
  end
  ```

### Test mode
For testing purposes mailgun can output emails to a local file instead of
actually sending them. Just set the `mode` configuration key to `:test`
and the `test_file_path` to where you want that file to appear.

```elixir
# lib/mailer.ex
defmodule MyApp.Mailer do
  use Mailgun.Client, domain: Application.get_env(:my_app, :mailgun_domain),
                      key: Application.get_env(:my_app, :mailgun_key),
                      mode: :test,
                      test_file_path: "/tmp/mailgun.json"

...
end
```
