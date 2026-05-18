# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module GmailSorter
  OLLAMA_CHAT_URL = URI('http://127.0.0.1:11434/api/chat')

  module_function

  def categorize(email, model:, categories:)
    category_list = categories.join(', ')
    system_prompt = <<~PROMPT.strip
      You are an email categorizer. Classify the email into one of these categories: #{category_list}.
      If truly none fit well, invent a concise PascalCase category name (1-2 words).
      Respond with JSON only, no explanation: {"category": "<name>"}
    PROMPT
    user_prompt = <<~PROMPT.strip
      From: #{email[:sender]}
      Subject: #{email[:subject]}
      Preview: #{email[:snippet]}
    PROMPT

    response = ollama_chat(
      model: model,
      messages: [
        { role: 'system', content: system_prompt },
        { role: 'user', content: user_prompt }
      ]
    )
    data = JSON.parse(response)
    category = data['category'].to_s.strip
    category.empty? ? 'Uncategorized' : category
  rescue StandardError
    'Uncategorized'
  end

  def ollama_chat(model:, messages:)
    body = {
      model: model,
      messages: messages,
      format: 'json',
      stream: false
    }
    http = Net::HTTP.new(OLLAMA_CHAT_URL.host, OLLAMA_CHAT_URL.port)
    request = Net::HTTP::Post.new(OLLAMA_CHAT_URL.path)
    request['Content-Type'] = 'application/json'
    request.body = JSON.generate(body)

    response = http.request(request)
    raise "Ollama request failed: #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body).dig('message', 'content')
  end
  private_class_method :ollama_chat
end
