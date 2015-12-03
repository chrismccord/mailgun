# Elixir Mailgun Client [![Build Status](https://travis-ci.org/chrismccord/mailgun.svg)](https://travis-ci.org/chrismccord/mailgun)


```elixir
# config/config.exs

config :my_app, mailgun_domain: "https://api.mailgun.net/v3/" <> "mydomain.com",
                mailgun_key: "key-##############"


# lib/mailer.ex
defmodule MyApp.Mailer do
  @config domain: Application.get_env(:my_app, :mailgun_domain),
          key: key: Application.get_env(:my_app, :mailgun_key)
  use Mailgun.Client, @config
                      

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

 # attachments expect a list of maps. Each map should have a filename and path/content

  def send_greetings(user, file_path) do
    send_email to: user.email,
               from: @from,
               subject: "Happy b'day",
               html: "<strong>Cheers!</strong>",
               attachments: [%{path: file_path, filename: "greetings.png"}]
  end

  def send_invoice(user) do
    pdf = Invoice.create_for(user) # a string
    send_email to: user.email,
               from: @from,
               subject: "Invoice",
               html: "<strong>Your Invoice</strong>",
               attachments: [%{content: pdf, filename: "invoice.pdf"}]
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
  @config domain: Application.get_env(:my_app, :mailgun_domain),
          key: Application.get_env(:my_app, :mailgun_key),
          mode: :test,
          test_file_path: "/tmp/mailgun.json"
  use Mailgun.Client, @config

...
end
```

### httpc options
Under the hood the client uses [`httpc`](http://erlang.org/doc/man/httpc.html)
to call Mailgun REST API. You can inject any valid `httpc` options to your
outbound requests by defining them within `httpc_opts` config entry:

```elixir
# lib/mailer.ex
defmodule MyApp.Mailer do
  @config domain: Application.get_env(:my_app, :mailgun_domain),
          key: Application.get_env(:my_app, :mailgun_key),
          httpc_opts: [connect_timeout: 2000, timeout: 3000]
  use Mailgun.Client, @config
...
```
