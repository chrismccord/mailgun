defmodule Mailgun.Client do

  @base_url "https://api.mailgun.net/v2/"

  defmacro __using__(config) do
    quote do
      def conf, do: unquote(config)
      def send_email(email) do
        unquote(__MODULE__).send_email(conf(), email)
      end
    end
  end

  def get_attachment(mailer, url) do
    config = mailer.conf
    request :get, url, "api", config[:key], ""
  end

  def send_email(conf, email) do
    request :post, url("/messages", conf[:domain]), "api", conf[:key], URI.encode_query(
      to: Dict.fetch!(email, :to),
      from: Dict.fetch!(email, :from),
      text: Dict.fetch!(email, :body),
      subject: Dict.get(email, :subject, "")
    )
  end

  def url(path, domain), do: Path.join([@base_url, domain, path])

  def request(method, url, user, pass, body) do
    url     = String.to_char_list(url)

    case method do
      :get ->
        headers = [auth_header(user, pass)]
        :httpc.request(:get, {url, headers}, [], body_format: :binary)
      _    ->
        ctype   = 'application/x-www-form-urlencoded'
        headers = [auth_header(user, pass), {'Content-Type', ctype}]
        :httpc.request(method, {url, headers, ctype, body}, [], body_format: :binary)
    end
    |> normalize_response
  end

  defp auth_header(user, pass) do
    {'Authorization', 'Basic ' ++ String.to_char_list(Base.encode64("#{user}:#{pass}"))}
  end

  defp normalize_response(response) do
    case response do
      {:ok, {{_httpvs, 200, _status_phrase}, json_body}} ->
        {:ok, json_body}
      {:ok, {{_httpvs, 200, _status_phrase}, _headers, json_body}} ->
        {:ok, json_body}
      {:ok, {{_httpvs, status, _status_phrase}, json_body}} ->
        {:error, status, json_body}
      {:ok, {{_httpvs, status, _status_phrase}, _headers, json_body}} ->
        {:error, status, json_body}
      {:error, reason} -> {:error, :bad_fetch, reason}
    end
  end
end
