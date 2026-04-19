---
name: youtube-transcript
description: "YouTube transcript extractor. This skill should be used when the user asks to 'get the transcript', 'transcribe this YouTube video', 'extract captions', 'summarize this video', or provides a YouTube URL for analysis."
---

# YouTube Transcript Extractor

## Overview

Extract transcripts from YouTube videos and save them as structured markdown files.
Uses `youtube-transcript-api` (Python) — no API key, no browser, no auth required.

## Prerequisites

Install the library if not already available:

```bash
pip install --user --break-system-packages youtube-transcript-api
```

Verify: `python3 -c "from youtube_transcript_api import YouTubeTranscriptApi; print('OK')"`

## Process

### 1. Parse the URL

Extract the video ID from common YouTube URL formats:

| Format | Example |
|--------|---------|
| Standard | `https://www.youtube.com/watch?v=VIDEO_ID` |
| Short | `https://youtu.be/VIDEO_ID` |
| With timestamp | `https://www.youtube.com/watch?v=VIDEO_ID&t=123s` |
| Embed | `https://www.youtube.com/embed/VIDEO_ID` |

Python extraction pattern:
```python
import re
def extract_video_id(url: str) -> str:
    patterns = [
        r'(?:v=|\/v\/|youtu\.be\/|\/embed\/)([a-zA-Z0-9_-]{11})',
    ]
    for p in patterns:
        match = re.search(p, url)
        if match:
            return match.group(1)
    return url  # assume raw ID
```

### 2. List Available Languages

Before fetching, check what's available:

```python
from youtube_transcript_api import YouTubeTranscriptApi

ytt_api = YouTubeTranscriptApi()
transcript_list = ytt_api.list(video_id)
for t in transcript_list:
    print(f"{t.language} ({t.language_code}) | auto: {t.is_generated}")
```

If the user requests a specific language, use it. Otherwise default to:
1. Manual English (`en`) if available
2. Auto-generated English if manual not available
3. First available language

### 3. Fetch and Format

```python
snippets = ytt_api.fetch(video_id, languages=['en'])

# Build timestamped lines
lines_ts = []
lines_plain = []
for s in snippets:
    minutes = int(s.start // 60)
    seconds = int(s.start % 60)
    text = s.text.replace('\n', ' ').strip()
    lines_ts.append(f"[{minutes:02d}:{seconds:02d}] {text}")
    lines_plain.append(text)
```

### 4. Save to Markdown

Output location: project `data/transcripts/` directory (create if needed).
Filename: `transcript_{video_id}.md`

Template:
```markdown
# Transcript: {url}

**Video ID**: {video_id}
**Language**: {language} ({auto/manual})
**Extracted**: {date}

---

## Timestamped Transcript

[00:01] First line of speech...
[00:05] Second line...

---

## Plain Text

Full concatenated text without timestamps...
```

### 5. Report to User

After saving, display:
- File path (absolute)
- Segment count
- Duration (~MM:SS from last segment)
- File size
- First 3-5 lines preview

## Advanced Features

### Translation

If the user wants a translated transcript:
```python
transcript_list = ytt_api.list(video_id)
transcript = transcript_list.find_transcript(['en'])
translated = transcript.translate('fr')  # or any language code
snippets = translated.fetch()
```

### Batch Processing

For multiple URLs, process sequentially and save each to its own file.
Report a summary table at the end:

| # | Video ID | Duration | Segments | File |
|---|----------|----------|----------|------|
| 1 | abc123   | 15:30    | 245      | transcript_abc123.md |
| 2 | def456   | 42:10    | 890      | transcript_def456.md |

### SRT/VTT Export

If the user wants subtitle format:
```python
from youtube_transcript_api.formatters import SRTFormatter, WebVTTFormatter

formatter = SRTFormatter()
srt_output = formatter.format_transcript(snippets)
# Save as .srt file
```

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| `TranscriptsDisabled` | Video has no captions | Inform user, suggest alternatives |
| `NoTranscriptFound` | Language not available | List available languages, ask user to pick |
| `VideoUnavailable` | Private/deleted/region-locked | Inform user |
| Network error | Connectivity | Retry once, then report |

## Notes

- Auto-generated transcripts may contain errors (no punctuation, wrong words)
- Very long videos (2h+) may produce large files (500KB+)
- The library does NOT download video/audio — only text captions
- Works without any API key or authentication
