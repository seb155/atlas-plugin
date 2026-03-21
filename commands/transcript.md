---
name: transcript
description: "Extract YouTube video transcript to markdown file"
arguments:
  - name: url
    description: "YouTube video URL or video ID"
    required: true
---

# /transcript — YouTube Video Transcript Extractor

Invoke Skill `atlas-admin:youtube-transcript` with the provided arguments.

Extract the transcript from the YouTube video URL, save as timestamped markdown,
and report the file path.

**Usage**: `/transcript <youtube-url>`

**Examples**:
- `/transcript https://www.youtube.com/watch?v=abc123`
- `/transcript https://youtu.be/abc123`
- `/transcript abc123`

ARGUMENTS: $ARGUMENTS
