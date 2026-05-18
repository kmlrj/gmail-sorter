# frozen_string_literal: true

module GmailSorter
  DEFAULT_CATEGORIES = [
    'Work',
    'Finance',
    'Newsletters',
    'Personal',
    'Receipts',
    'Promotions',
    'Social',
    'Travel',
    'Security',
    'Notifications'
  ].freeze

  OLLAMA_MODEL = 'llama3.2:3b'
  DEFAULT_FETCH_COUNT = 50
  LABEL_PREFIX = 'AI/'

  CREDENTIALS_PATH = 'credentials/credentials.json'
  TOKEN_PATH = 'credentials/token.json'

  GMAIL_SCOPES = ['https://www.googleapis.com/auth/gmail.modify'].freeze
end
