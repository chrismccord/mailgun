defmodule MailgunTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Httpc

  @success_json "{\n  \"message\": \"Queued. Thank you.\",\n  \"id\": \"<someuser@somedomain.mailgun.org>\"\n}"
  @error_json "{\n  \"message\": \"'to' parameter is not a valid address. please check documentation\"\n}"

  setup do
    Mailgun.start

    on_exit &Mailgun.stop/0
  end

  test "url returns the full url joined with the path and domain config" do
    assert Mailgun.Client.url("/messages", "https://api.mailgun.net/v3/mydomain.com") ==
      "https://api.mailgun.net/v3/mydomain.com/messages"
  end

  test "send_email returns {:ok, response} if sent successfully" do
    config = [domain: "https://api.mailgun.net/v3/mydomain.test", key: "my-key"]
    set_conf config
    use_cassette :stub, [url: "https://api.mailgun.net/v3/mydomain.test/messages",
                         method: "post",
                         status_code: ["HTTP/1.1", 200, "OK"],
                         body: @success_json] do

      {:ok, body} = Mailgun.Client.send_email to: "foo@bar.test",
                                              from: "foo@bar.test",
                                              subject: "hello!",
                                              text: "How goes it?"

      assert body == @success_json
    end
  end

  test "send_email returns {:error, reason} if send failed" do
    set_conf [domain: "https://api.mailgun.net/v3/mydomain.test", key: "my-key"]
    use_cassette :stub, [url: "https://api.mailgun.net/v3/mydomain.test/messages",
                         method: "post",
                         status_code: ["HTTP/1.1", 400, "BAD REQUEST"],
                         body: @error_json] do

      {:error, status, body} = Mailgun.Client.send_email to: "foo@bar.test",
                                                         from: "foo@bar.test",
                                                         subject: "hello!",
                                                         text: "How goes it?"

      assert status == 400
      assert body == @error_json
    end
  end

  test "sending in test mode writes the mail fields to a file" do
    file_path = "/tmp/mailgun.json"
    set_conf [domain: "https://api.mailgun.net/v3/mydomain.test", key: "my-key", mode: :test, test_file_path: file_path]
    {:ok, _} = Mailgun.Client.send_email to: "foo@bar.test",
                                         from: "foo@bar.test",
                                         subject: "hello!",
                                         text: "How goes it?"

    file_contents = File.read!(file_path)
    assert file_contents == "{\"to\":\"foo@bar.test\",\"text\":\"How goes it?\",\"subject\":\"hello!\",\"from\":\"foo@bar.test\"}"
  end

  defp set_conf(config) do
    config |> Enum.each(fn {k, v} -> Application.put_env(:mailgun, k, v) end)
  end

end
