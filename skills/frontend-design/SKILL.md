---
name: frontend-design
description: "Distinctive, production-grade frontend UI/UX implementation. This skill should be used when the user asks to 'design a page', 'build a UI component', 'create a frontend', 'implement this design', 'make it look better', 'build a web interface', or needs creative, polished UI work that avoids generic AI aesthetics."
---

# Frontend Design

Create distinctive, production-grade frontend interfaces with exceptional design quality.
Implement real working code with bold aesthetic choices. Avoid generic AI aesthetics.

## Design Thinking (BEFORE coding)

### 1. Understand Context
- **Purpose**: What problem does this interface solve? Who uses it?
- **Personas**: Which project personas are affected?
- **Constraints**: Framework (React/Vue/HTML), performance, accessibility requirements
- **Existing patterns**: Check .blueprint/UX-VISION.md and .claude/rules/ux-rules.md

### 2. Choose Aesthetic Direction
Commit to a BOLD direction — intentionality matters more than intensity:
- Brutally minimal, maximalist, retro-futuristic, organic/natural
- Luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw
- Art deco/geometric, soft/pastel, industrial/utilitarian
- Or create a unique direction that fits the context

Present 2-3 aesthetic options via AskUserQuestion with mood descriptions.

### 3. Key Aesthetic Principles

**Typography**: Choose distinctive, characterful fonts. NEVER default to Inter, Roboto, Arial, or system fonts. Pair a display font with a refined body font.

**Color & Theme**: Commit to a cohesive palette. Use CSS variables for consistency. Dominant colors with sharp accents beat timid, evenly-distributed palettes.

**Motion**: Prioritize high-impact moments — one orchestrated page load with staggered reveals creates more delight than scattered micro-interactions. Use CSS animations or Motion library (React).

**Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Grid-breaking elements. Generous negative space OR controlled density.

**Backgrounds & Details**: Atmosphere and depth over solid colors. Gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows.

## Implementation

### 4. Build Production Code
- Functional, responsive, accessible
- Cohesive with the chosen aesthetic point-of-view
- Meticulously refined in every detail
- Match implementation complexity to the vision:
  - Maximalist → elaborate code with extensive animations
  - Minimalist → restraint, precision, careful spacing/typography

### 5. Project Integration
When building within an existing project:
- Follow `--syn-*` CSS variable theme system (check ux-rules.md)
- Use existing component library (shadcn/ui, AG Grid conventions)
- Maintain design system consistency while adding character
- Loading, error, and empty states for every component

## Anti-Patterns (NEVER)

- Generic AI aesthetics: Inter font, purple gradients on white, predictable layouts
- Cookie-cutter components without context-specific character
- Same design choices across different generations
- Overused fonts: Space Grotesk, Inter, Roboto, Arial
- Cliched color schemes (particularly blue/purple gradients)

## HITL Gates

- After aesthetic direction → present options via AskUserQuestion
- After mockup/wireframe → validate layout before coding
- After first implementation → screenshot review with user
- Before shipping → final visual QA approval
