# Elixir Mailgun Client


```elixir
# config/config.exs

config :my_app, mailgun_domain: "foo@bar.com",
                mailgun_key: System.get_env("MAILGUN_KEY")


# lib/mailer.ex
defmodule MyApp.Mailer do
  use Mailgun.Client, domain: Application.get_env(:my_app, :mailgun_domain),
                      key: Application.get_env(:my_app, :mailgun_key)

  @from "info@example.com"

  def send_welcome_email(user) do
    send_email to: user.email,
               from: @from,
               subject: "hello!",
               body: "Welcome!"
  end
end


iex> MyApp.Mailer.send_welcome_email(user)
{:ok, ...}
```

