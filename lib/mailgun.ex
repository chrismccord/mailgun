defmodule Mailgun do

  def start do
    ensure_started :inets
    ensure_started :ssl
    :ok
  end

  defp ensure_started(module) do
    case module.start do
      :ok -> :ok
      {:error, {:already_started, _module}} -> :ok
    end
  end
end
