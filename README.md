# Gmail Inbox Sorter

Sorts your Gmail inbox into categories using a locally-running Ollama LLM. No email data leaves your machine.

## Prerequisites

### 1. Ollama

```bash
brew install ollama
ollama pull llama3.2:3b   # ~2 GB, fast and accurate enough for this task
ollama serve              # keep running in a terminal tab
```

### 2. Gmail API credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/) and create a new project.
2. Enable the **Gmail API** for the project.
3. Go to **APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID**.
4. Application type: **Desktop app**.
5. Download the JSON file and save it as:
   ```
   gmail-sorter/credentials/credentials.json
   ```

### 3. Ruby dependencies

Requires Ruby 3.2+ (Homebrew: `brew install ruby`, then ensure `/opt/homebrew/opt/ruby/bin` is on your `PATH`).

```bash
bundle install
```

## Usage

```bash
# Preview categories without applying labels (safe first run)
ruby main.rb --count 10 --dry-run

# Apply labels to 50 most recent unread emails
ruby main.rb

# Use a different model or process more emails
ruby main.rb --model gemma2:2b --count 100
```

### CLI flags

| Flag | Default | Description |
|------|---------|-------------|
| `--count N` | 50 | Number of unread inbox emails to process |
| `--model NAME` | `llama3.2:3b` | Ollama model to use |
| `--dry-run` | off | Print categories without applying labels |

## How it works

1. **Auth**: First run opens a browser for Gmail OAuth consent. Token is saved to `credentials/token.json`.
2. **Fetch**: Pulls up to N unread messages from your inbox (subject, sender, snippet only).
3. **Categorize**: Each email is sent to the local Ollama model with a prompt asking it to pick from a predefined list or coin a new PascalCase category.
4. **Label**: Creates `AI/<Category>` labels in Gmail if they don't exist, then applies them to each message.

## Default categories

`Work`, `Finance`, `Newsletters`, `Personal`, `Receipts`, `Promotions`, `Social`, `Travel`, `Security`, `Notifications`

The LLM may invent additional categories when none of the above fit.

## Customizing categories

Edit `DEFAULT_CATEGORIES` in `lib/config.rb`.
