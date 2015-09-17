defmodule Mailgun do

  @app :mailgun

  def start do
    Application.ensure_all_started @app
  end

  end
end
