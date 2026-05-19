# frozen_string_literal: true

require 'json'
require 'webrick'
require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'

module GmailSorter
  LABEL_COLORS = [
    { background_color: '#4986e7', text_color: '#ffffff' },
    { background_color: '#16a765', text_color: '#ffffff' },
    { background_color: '#fb4c2f', text_color: '#ffffff' },
    { background_color: '#ffad46', text_color: '#ffffff' },
    { background_color: '#a479e2', text_color: '#ffffff' },
    { background_color: '#0d3472', text_color: '#ffffff' },
    { background_color: '#ac2b16', text_color: '#ffffff' },
    { background_color: '#076239', text_color: '#ffffff' }
  ].freeze

  module_function

  @color_index = 0

  def build_service(credentials_path, token_path)
    raise Errno::ENOENT, credentials_path unless File.exist?(credentials_path)

    client_id = Google::Auth::ClientId.from_file(credentials_path)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: token_path)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, GMAIL_SCOPES, token_store)

    credentials = authorizer.get_credentials('default')
    credentials = run_local_oauth(authorizer) unless credentials

    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = credentials
    service
  end

  def run_local_oauth(authorizer)
    received_code = nil
    port = 9292
    server = WEBrick::HTTPServer.new(
      Port: port,
      BindAddress: '127.0.0.1',
      Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
      AccessLog: []
    )
    base_url = "http://127.0.0.1:#{port}"

    server.mount_proc '/oauth2callback' do |req, res|
      received_code = req.query['code']
      res.status = 200
      res['Content-Type'] = 'text/html'
      res.body = '<h1>Authorization complete. You can close this tab.</h1>'
      Thread.new { server.shutdown }
    end

    url = authorizer.get_authorization_url(base_url: base_url)
    warn "Opening browser for Gmail authorization..."
    system('open', url) if RUBY_PLATFORM.match?(/darwin/)
    warn "If the browser did not open, visit:\n#{url}\n"

    server_thread = Thread.new { server.start }
    sleep 0.1 until received_code
    server_thread.join

    authorizer.get_and_store_credentials_from_code(
      user_id: 'default',
      code: received_code,
      base_url: base_url
    )
  end

  def fetch_unread_emails(service, count)
    results = service.list_user_messages(
      'me',
      q: 'is:unread in:inbox',
      max_results: count
    )
    messages = results.messages || []
    messages.map do |msg|
      detail = service.get_user_message(
        'me',
        msg.id,
        format: 'metadata',
        metadata_headers: %w[From Subject]
      )
      headers = (detail.payload&.headers || []).each_with_object({}) do |header, acc|
        acc[header.name] = header.value
      end
      {
        id: msg.id,
        subject: headers['Subject'] || '(no subject)',
        sender: headers['From'] || '(unknown)',
        snippet: detail.snippet || ''
      }
    end
  end

  def list_labels(service)
    result = service.list_user_labels('me')
    (result.labels || []).each_with_object({}) do |label, acc|
      acc[label.name] = label.id
    end
  end

  def create_label(service, name)
    color = LABEL_COLORS[@color_index % LABEL_COLORS.length]
    @color_index += 1

    label = service.create_user_label(
      'me',
      Google::Apis::GmailV1::Label.new(
        name: name,
        label_list_visibility: 'labelShow',
        message_list_visibility: 'show',
        color: Google::Apis::GmailV1::LabelColor.new(
          background_color: color[:background_color],
          text_color: color[:text_color]
        )
      )
    )
    label.id
  end

  def apply_label(service, message_id, label_id)
    service.modify_message(
      'me',
      message_id,
      Google::Apis::GmailV1::ModifyMessageRequest.new(add_label_ids: [label_id])
    )
  end
end
