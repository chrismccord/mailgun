defmodule Mailgun do
  @moduledoc "Elixir Mailgun Client"

  def start do
    Application.ensure_all_started(:mailgun)
    :ok
  end
end
