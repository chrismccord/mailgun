defmodule Mailgun do

  @app :mailgun

  def start do
    Application.ensure_all_started @app
  end

  def stop do
    Application.stop @app
    Application.unload @app
  end

end
