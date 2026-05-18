#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('lib', __dir__))

require 'optparse'
require 'pastel'
require 'tty-spinner'
require 'tty/table'

require 'config'
require 'gmail_client'
require 'categorizer'

module GmailSorter
  module CLI
    module_function

    def get_or_create_label(service, label_name, label_cache)
      full_name = "#{LABEL_PREFIX}#{label_name}"
      unless label_cache.key?(full_name)
        label_id = create_label(service, full_name)
        label_cache[full_name] = label_id
        return [label_id, true]
      end
      [label_cache[full_name], false]
    end

    def run(argv = ARGV)
      options = {
        count: DEFAULT_FETCH_COUNT,
        model: OLLAMA_MODEL,
        dry_run: false
      }

      OptionParser.new do |opts|
        opts.banner = 'Usage: ruby main.rb [options]'
        opts.on('--count N', Integer, "Number of unread emails to process (default: #{DEFAULT_FETCH_COUNT})") do |n|
          options[:count] = n
        end
        opts.on('--model NAME', "Ollama model to use (default: #{OLLAMA_MODEL})") do |name|
          options[:model] = name
        end
        opts.on('--dry-run', 'Categorize but do not apply Gmail labels') do
          options[:dry_run] = true
        end
      end.parse!(argv)

      pastel = Pastel.new

      dry_run_suffix = options[:dry_run] ? " #{pastel.yellow('(dry-run)')}" : ''
      puts "\n#{pastel.bold('Gmail Inbox Sorter')} — model: #{pastel.cyan(options[:model])}, " \
           "count: #{pastel.cyan(options[:count].to_s)}#{dry_run_suffix}"

      puts pastel.dim('Authenticating with Gmail...')
      begin
        service = build_service(CREDENTIALS_PATH, TOKEN_PATH)
      rescue Errno::ENOENT
        warn pastel.red("Error: credentials.json not found at #{pastel.bold(CREDENTIALS_PATH)}.")
        warn 'See the README for Google Cloud setup instructions.'
        exit 1
      end

      puts pastel.dim("Fetching up to #{options[:count]} unread emails...")
      emails = fetch_unread_emails(service, options[:count])
      if emails.empty?
        puts pastel.yellow('No unread emails found in inbox.')
        return
      end

      puts "Found #{pastel.bold(emails.length.to_s)} unread email(s).\n"

      label_cache = list_labels(service)
      rows = []
      labels_created = 0
      labels_reused = 0

      spinner = TTY::Spinner.new(
        ':spinner Categorizing...',
        format: :dots,
        hide_cursor: true
      )
      spinner.auto_spin

      emails.each do |email|
        spinner.update(title: "Categorizing: #{email[:subject][0, 50]}")
        category = categorize(email, model: options[:model], categories: DEFAULT_CATEGORIES)
        full_label = "#{LABEL_PREFIX}#{category}"

        if options[:dry_run]
          label_display = pastel.dim("(dry-run) #{full_label}")
        else
          label_id, created = get_or_create_label(service, category, label_cache)
          apply_label(service, email[:id], label_id)
          if created
            labels_created += 1
          else
            labels_reused += 1
          end
          label_display = full_label
        end

        rows << [
          email[:sender][0, 60],
          email[:subject][0, 80],
          pastel.green.bold(category),
          label_display
        ]
      end

      spinner.stop

      table = TTY::Table.new(
        header: ['From', 'Subject', 'Category', 'Label'],
        rows: rows
      )
      puts table.render(:unicode, padding: [0, 1])

      if options[:dry_run]
        puts "\n#{pastel.yellow('Dry-run complete — no labels applied.')}"
      else
        puts "\n#{pastel.green('Done.')} #{emails.length} email(s) processed. " \
             "Labels created: #{pastel.bold(labels_created.to_s)}, " \
             "reused: #{pastel.bold(labels_reused.to_s)}."
      end
    end
  end
end

GmailSorter::CLI.run if $PROGRAM_NAME == __FILE__
