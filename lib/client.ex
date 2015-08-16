defmodule Mailgun.Client do

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
    request :get, url, "api", config[:key], [], "", ""
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

    request(:post, url("/messages", conf[:domain]), "api", conf[:key], [], ctype, body)
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
        data = :erlang.binary_to_list(File.read!(upload.path))
        [{:attachment, String.to_char_list(upload.filename), data} | acc]
      end)

    body = format_multipart_formdata(boundary, attrs, attachments)

    headers = [{'Content-Length', :erlang.integer_to_list(:erlang.length(attachments))} | headers]

    request(:post, url("/messages", conf[:domain]), "api", conf[:key], headers, ctype, body)
  end
  def log_email(conf, email) do
    json = email
    |> Enum.into(%{})
    |> Poison.encode!
    File.write(conf[:test_file_path], json)
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

  def request(method, url, user, pass, headers, ctype, body) do
    url     = String.to_char_list(url)

    case method do
      :get ->
        headers = headers ++ [auth_header(user, pass)]
        :httpc.request(:get, {url, headers}, [], body_format: :binary)
      _    ->
        headers = headers ++ [auth_header(user, pass), {'Content-Type', ctype}]
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
