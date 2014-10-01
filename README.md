# Elixir Mailgun Client


```elixir
# config/config.exs

config :mailgun, domain: "foo@bar.com",
                 key: System.get_env("MAILGUN_KEY")


# lib/mailer.ex
defmodule MyApp.Mailer do
  use Mailgun.Client, domain: Application.get_env(:mailgun, :domain),
                      key: Application.get_env(:mailgun, :key)

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

