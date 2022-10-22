defmodule Mailgun.Client do
  @moduledoc """
  Module to interact with Mailgun and send emails.

  ## Configuration

      # config/config.exs
      config :my_app,
        mailgun_domain: "https://api.mailgun.net/v3/mydomain.com",
        mailgun_key: "key-##############"

      # lib/user_mailer.ex
      defmodule MyApp.UserMailer do
        @config domain: Application.get_env(:my_app, :mailgun_domain),
                key: Application.get_env(:my_app, :mailgun_key),
                mode: Mix.env
        Mailgun.Client, @config
      end

  ## Sending Emails

  Invoke `send_email/1` method with a keyword list of `:from`, `:to`, `:subject`,
  `:text`, `:html`, `:attachments`.

      # lib/user_mailer.ex
      defmodule MyApp.UserMailer do
        @config domain: Application.get_env(:my_app, :mailgun_domain),
                key: Application.get_env(:my_app, :mailgun_key),
                mode: Mix.env
        use Mailgun.Client, @config

        def send_welcome_text_email(email) do
          send_email to: email,
                     from: "info@example.com",
                     subject: "hello!",
                     text: "Welcome!"
        end

        def send_welcome_html_email(user) do
          send_email to: user.email,
                    from: "info@example.com",
                    subject: "hello!",
                    html: "<strong>Welcome!</strong>"
        end
      end

      $ iex -S mix
      iex> MyApp.UserMailer.send_welcome_text_email("us@example.com")

  ## Send an attachment in the email

  Pass the `attachments` option which is a list of maps. Each map
  (attachment) should have a `filename` and a `path` or `content`.

  Options for each attachment:
    * `filename` - a string eg: "sample.png"
    * `path` - a string eg: "/tmp/sample.png"
    * `content` - a string eg: File.read!("/tmp/sample.png")

  If there is a file_path in the storage that needs to sent in the email,
  pass that as a map with `path` and `filename`.

      def send_greetings(user, file_path) do
        send_email to: user.email,
                  from: @from,
                  subject: "Happy b'day",
                  html: "<strong>Cheers!</strong>",
                  attachments: [%{path: file_path, filename: "greetings.png"}]
      end

  If a file content is created on the fly using some generator. That file content
  can be passed(without being written on to the disk) in the map with
  `content` and `filename`.

      def send_invoice(user) do
        pdf = Invoice.create_for(user) # a string
        send_email to: user.email,
                   from: @from,
                   subject: "Invoice",
                   html: "<strong>Your Invoice</strong>",
                   attachments: [%{content: pdf, filename: "invoice.pdf"}]
      end
  """

  defmacro __using__(config) do
    quote do
      @conf unquote(config)
      def conf, do: @conf
      def send_email(email) do
        unquote(__MODULE__).send_email(conf(), email)
      end
    end
  end

  def get_attachment(mailer, url) do
    config = mailer.conf
    request config, :get, url, "api", config[:key], [], "", ""
  end

  def send_email(conf, email) do
    do_send_email(conf[:mode], conf, email)
  end
  defp do_send_email(:test, conf, email) do
    log_email(conf, email)
    {:ok, "OK"}
  end
  defp do_send_email(_, conf, email) do
    case email[:attachments] do
      atts when atts in [nil, []] ->
        send_without_attachments(conf, email)
      atts when is_list(atts) ->
        send_with_attachments(conf, Dict.delete(email, :attachments), atts)
    end
  end
  defp send_without_attachments(conf, email) do
    attrs = Dict.merge(email, %{
      to: Dict.fetch!(email, :to),
      from: Dict.fetch!(email, :from),
      text: Dict.get(email, :text, ""),
      html: Dict.get(email, :html, ""),
      subject: Dict.get(email, :subject, ""),
    })
    ctype   = 'application/x-www-form-urlencoded'
    body    = URI.encode_query(Dict.drop(attrs, [:attachments]))

    request(conf, :post, url("/messages", conf[:domain]), "api", conf[:key], [], ctype, body)
  end
  defp send_with_attachments(conf, email, attachments) do
    attrs =
      email
      |> Dict.merge(%{
        to: Dict.fetch!(email, :to),
        from: Dict.fetch!(email, :from),
        text: Dict.get(email, :text, ""),
        html: Dict.get(email, :html, ""),
        subject: Dict.get(email, :subject, "")})
      |> Enum.map(fn
        {k, v} when is_binary(v) -> {k, String.to_char_list(v)}
        {k, v} -> {k, v}
      end)
      |> Enum.into(%{})

    headers  = []
    boundary = '------------a450glvjfEoqerAc1p431paQlfDac152cadADfd'
    ctype    = :lists.concat(['multipart/form-data; boundary=', boundary])

    attachments =
      Enum.reduce(attachments, [], fn upload, acc ->
        data = parse_attachment(upload) |> :erlang.binary_to_list
        [{:attachment, String.to_char_list(upload.filename), data} | acc]
      end)

    body = format_multipart_formdata(boundary, attrs, attachments)

    headers = [{'Content-Length', :erlang.integer_to_list(:erlang.length(attachments))} | headers]

    request(conf, :post, url("/messages", conf[:domain]), "api", conf[:key], headers, ctype, body)
  end

  defp parse_attachment(%{content: content}), do: content
  defp parse_attachment(%{path: path}), do: File.read!(path)

  def log_email(conf, email) do
    json = Poison.encode!(parse_log_file(conf) ++ [Enum.into(email, %{})])
    File.write(conf[:test_file_path], json)
  end

  defp parse_log_file(conf) do
    case File.read(conf[:test_file_path]) do
      {:ok, contents} ->
        Poison.Parser.parse!(contents)
      {:error, _} ->
        []
    end
  end

  defp format_multipart_formdata(boundary, fields, files) do
    field_parts = Enum.map(fields, fn {field_name, field_content} ->
      [:lists.concat(['--', boundary]),
       :lists.concat(['Content-Disposition: form-data; name=\"', :erlang.atom_to_list(field_name),'\"']),
       '',
       field_content]
    end)
    field_parts2 = :lists.append(field_parts)
    file_parts = Enum.map(files, fn {field_name, file_name, file_content} ->
      [:lists.concat(['--', boundary]),
       :lists.concat(['Content-Disposition: format-data; name=\"', :erlang.atom_to_list(field_name), '\"; filename=\"', file_name, '\"']),
       :lists.concat(['Content-Type: ', 'application/octet-stream']),
       '',
       file_content]
    end)
    file_parts2 = :lists.append(file_parts)
    ending_parts = [:lists.concat(['--', boundary, '--']), '']
    parts = :lists.append([field_parts2, file_parts2, ending_parts])

    :string.join(parts, '\r\n')
  end

  def url(path, domain), do: Path.join([domain, path])

  def request(conf, method, url, user, pass, headers, ctype, body) do
    url  = String.to_char_list(url)
    opts = conf[:httpc_opts] || []

    case method do
      :get ->
        headers = headers ++ [auth_header(user, pass)]
        :httpc.request(:get, {url, headers}, opts, body_format: :binary)
      _    ->
        headers = headers ++ [auth_header(user, pass), {'Content-Type', ctype}]
        :httpc.request(method, {url, headers, ctype, body}, opts, body_format: :binary)
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
