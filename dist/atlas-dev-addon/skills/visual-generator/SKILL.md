---
name: visual-generator
description: "Generate diagrams, infographics, photos via Gemini API (Imagen 4 + Flash). Style presets, text overlay mode, HITL iteration."
effort: medium
---

# Visual Generator — AI Image Generation for Presentations & Docs

Generate professional visuals using Google Gemini API (Imagen 4 Ultra/Standard/Fast + Gemini Flash Image).

## Triggers

- `/atlas visual` or `/atlas image`
- "generate a diagram", "create an infographic", "make a visual"
- "generate presentation visuals", "slide images"

## Prerequisites

- `GEMINI_API_KEY` in `~/.env` (Google AI Studio API key)
- Python venv with `google-genai` and `Pillow` packages
- If venv missing, create: `python3 -m venv /tmp/gemini-venv && /tmp/gemini-venv/bin/pip install google-genai Pillow`

## Process

### 1. Parse Request

Determine the visual type from user input:

| Type | Trigger keywords | Best model |
|------|-----------------|------------|
| `diagram` | diagram, flowchart, architecture, cross-section | Gemini Flash Image |
| `infographic` | infographic, chart, comparison, timeline | Gemini Flash Image |
| `photo` | photo, hero, landscape, realistic | Imagen 4 Ultra |
| `illustration` | illustration, flat, vector, icon | Imagen 4 Standard |

### 2. Build Prompt

Assemble the prompt from user description + style preset + type-specific instructions.

**Style presets** (apply automatically based on project context or user flag):

| Preset | Colors | Use case |
|--------|--------|----------|
| `corporate-gold` | Gold (#D4A843), Navy (#1B2A4A), White bg | GMS, mining, boardroom |
| `synapse-emerald` | Emerald (#10B981), Dark (#18181B), Zinc | Synapse product, tech |
| `minimal` | Black, White, 1 accent color | Clean consulting, any |
| `axoiq` | Slate blue, Amber accent, Dark bg | AXOIQ brand |

**Type-specific prompt suffixes**:

For `diagram`:
```
Style: Clean flat vector diagram. Geometric shapes. Thin callout lines.
Small clean sans-serif font. White background. Professional consulting quality.
Landscape 16:9. No watermarks.
```

For `photo`:
```
Style: Professional photorealistic. Cinematic composition. High quality.
Suitable for corporate presentation. Landscape 16:9. No watermarks.
```

For `infographic`:
```
Style: Modern flat infographic. Clean typography. Well-spaced sections.
Data visualization aesthetic. White background. Landscape 16:9. No watermarks.
```

### 3. Handle Text in Images

AI image generation produces spelling errors in non-English text. Apply this strategy:

**Decision flow**:
```
Does the visual need text labels?
├── YES, few labels (< 5 short words) → Include in prompt, verify output
├── YES, many labels or French text → Generate WITHOUT text, add overlay later
└── NO → Generate as-is
```

**When generating without text**, append to prompt:
```
ABSOLUTELY NO TEXT. No labels. No titles. No words. Just the visual.
```

**Text overlay options** (suggest to user):
- CSS/SVG overlay in pitch site (best for web)
- Canva/Figma overlay (best for PPTX)
- HTML canvas with positioned divs

### 4. Generate Image

Use this Python execution pattern:

```python
# Load API key from ~/.env
# Initialize: from google import genai; client = genai.Client(api_key=KEY)

# For diagrams/infographics (Gemini Flash Image — better text):
response = client.models.generate_content(
    model='gemini-2.5-flash-image',
    contents=prompt,
    config=types.GenerateContentConfig(
        response_modalities=['IMAGE', 'TEXT'],
    )
)

# For photos/illustrations (Imagen 4 — better visuals):
response = client.models.generate_images(
    model='imagen-4.0-generate-001',        # or ultra, or fast
    prompt=prompt,
    config=types.GenerateImagesConfig(
        number_of_images=1,
        aspect_ratio='16:9',                 # or '1:1', '9:16', '4:3', '3:4'
    )
)
```

**Available Imagen 4 models** (use appropriate tier):

| Model | Quality | Speed | Use when |
|-------|---------|-------|----------|
| `imagen-4.0-ultra-generate-001` | Highest | Slow | Final hero visuals, key slides |
| `imagen-4.0-generate-001` | High | Medium | General use, iteration |
| `imagen-4.0-fast-generate-001` | Good | Fast | Rapid prototyping, exploration |

### 5. Save & Display

- Save to `presentations/visuals/` (or user-specified directory)
- Filename: `{slide_or_name}-{description}-{timestamp}.png`
- Open with `xdg-open` so user sees it immediately
- Show inline via Read tool as well
- ALWAYS show the generated image to the user — never skip this step

### 6. HITL Iteration

After showing the image, ask user:
- Keep / iterate / regenerate / change style
- If iterating: adjust prompt based on feedback, regenerate
- Max 5 iterations per visual before suggesting a different approach
- Save all versions (v1, v2, ...) — never overwrite previous

When done, copy final version as `{name}-FINAL.png`.

## Prompt Engineering Tips

### What works well:
- "flat vector diagram" for clean diagrams
- "professional corporate infographic" for data visuals
- Explicit color palette ("gold #D4A843 and navy #1B2A4A only")
- "Landscape 16:9" for presentation slides
- "No watermarks" to avoid model artifacts
- Listing exact label text with "MUST BE EXACTLY AS WRITTEN"

### What doesn't work:
- Long French text (will have spelling errors)
- Complex multi-paragraph labels (use short keywords instead)
- Requesting specific fonts (models ignore this)
- Too many constraints in one prompt (simplify)

### Text accuracy hierarchy:
1. English short labels — most reliable
2. French short keywords (2-3 words) — usually OK
3. French sentences — unreliable, use no-text mode

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| `GEMINI_API_KEY not found` | Missing in ~/.env | Guide user to create key at aistudio.google.com |
| `ModuleNotFoundError: google.genai` | Venv missing | Create: `python3 -m venv /tmp/gemini-venv && .../pip install google-genai Pillow` |
| `404 model not found` | Wrong model name | List available: `client.models.list()`, filter for imagen/image |
| Safety filter block | Prompt flagged | Rephrase prompt, remove potentially sensitive content |
| Empty response | Generation failed | Retry with different model (Flash → Imagen or vice versa) |

## Examples

```
User: /atlas visual diagram "4 circles converging to center, labeled RH, G Mining Way, Processus, Observabilité" --style corporate-gold

User: /atlas visual photo "golden sunrise over mining mountain landscape, cinematic" --model ultra

User: /atlas visual infographic "5-step timeline: Observer, Connecter, Capturer, Mesurer, Évoluer" --no-text

User: /atlas visual mine-section "underground gold mine cross-section with 4 levels" --style corporate-gold
```
