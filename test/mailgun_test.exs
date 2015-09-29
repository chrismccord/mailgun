defmodule MailgunTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Httpc

  @success_json "{\n  \"message\": \"Queued. Thank you.\",\n  \"id\": \"<someuser@somedomain.mailgun.org>\"\n}"
  @error_json "{\n  \"message\": \"'to' parameter is not a valid address. please check documentation\"\n}"

  setup_all do
    Mailgun.start
  end

  test "url returns the full url joined with the path and domain config" do
    assert Mailgun.Client.url("/messages", "https://api.mailgun.net/v3/mydomain.com") ==
      "https://api.mailgun.net/v3/mydomain.com/messages"
  end

  test "url returns the full url joined with the path and domain config (env var)" do
    System.put_env %{
      "MAILGUN_DOMAIN" => "https://api.mailgun.net/v3/mydomain.test"
    }

    assert Mailgun.Client.url("/messages", {:system, "MAILGUN_DOMAIN"}) ==
      "https://api.mailgun.net/v3/mydomain.test/messages"
  end

  test "mailers can use Client for configuration automation" do
    defmodule Mailer do
      use Mailgun.Client, domain: "https://api.mailgun.net/v3/mydomain.test", key: "my-key"
    end

    assert Mailer.__info__(:functions) |> Enum.member?({:send_email, 1})

  end

  test "send_email returns {:ok, response} if sent successfully" do
    config = [domain: "https://api.mailgun.net/v3/mydomain.test", key: "my-key"]
    use_cassette :stub, [url: "https://api.mailgun.net/v3/mydomain.test/messages",
                         method: "post",
                         status_code: ["HTTP/1.1", 200, "OK"],
                         body: @success_json] do

      {:ok, body} = Mailgun.Client.send_email config,
                                              to: "foo@bar.test",
                                              from: "foo@bar.test",
                                              subject: "hello!",
                                              text: "How goes it?"

      assert body == @success_json
    end
  end

  test "send_email returns {:error, reason} if send failed" do
    config = [domain: "https://api.mailgun.net/v3/mydomain.test", key: "my-key"]
    use_cassette :stub, [url: "https://api.mailgun.net/v3/mydomain.test/messages",
                         method: "post",
                         status_code: ["HTTP/1.1", 400, "BAD REQUEST"],
                         body: @error_json] do

      {:error, status, body} = Mailgun.Client.send_email config,
                                                         to: "foo@bar.test",
                                                         from: "foo@bar.test",
                                                         subject: "hello!",
                                                         text: "How goes it?"

      assert status == 400
      assert body == @error_json
    end
  end

  test "sending in test mode writes the mail fields to a file" do
    file_path = "/tmp/mailgun.json"
    config = [domain: "https://api.mailgun.net/v3/mydomain.test", key: "my-key", mode: :test, test_file_path: file_path]
    {:ok, _} = Mailgun.Client.send_email config,
      to: "foo@bar.test",
      from: "foo@bar.test",
      subject: "hello!",
      text: "How goes it?"

    file_contents = File.read!(file_path)
    assert file_contents == "{\"to\":\"foo@bar.test\",\"text\":\"How goes it?\",\"subject\":\"hello!\",\"from\":\"foo@bar.test\"}"
  end

end
