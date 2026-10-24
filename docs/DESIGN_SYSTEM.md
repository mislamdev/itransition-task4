# The design system of the application

The design of the application is built in **four layers**. Every layer only
uses the layer below it, therefore the whole application can be restyled by
touching a single file.

```
app/assets/stylesheets/
├── bootstrap.min.css           1. the CSS framework (Bootstrap 5.3 + Icons)
├── theme/
│   ├── tokens.css              2. THE TOKENS - the palette, the shapes, the type
│   ├── bootstrap-theme.css      3. the mapping of the tokens onto Bootstrap
│   └── components.css          4. the components of the application
└── application.css             5. the rules of the pages
```

The order of the `<link>` tags in the layouts is exactly this order —
the tokens have to come **after** Bootstrap, otherwise the framework would
overwrite them.

---

## 1. The tokens (`theme/tokens.css`)

The tokens are plain CSS custom properties on `:root`. They are the single
source of truth of the design:

| Group | Tokens |
|---|---|
| The accent | `--theme-primary`, `--theme-primary-strong`, `--theme-primary-soft` |
| The assistant | `--theme-accent`, `--theme-accent-strong`, `--theme-accent-soft` |
| The status | `--theme-success`, `--theme-danger`, `--theme-warning` (+ their `-soft` variants) |
| The neutrals | `--theme-slate-50` … `--theme-slate-900` |
| The surfaces | `--theme-bg`, `--theme-surface`, `--theme-surface-muted`, `--theme-border` |
| The text | `--theme-text`, `--theme-text-muted`, `--theme-text-subtle` |
| The shape | `--theme-radius-xs` … `--theme-radius-xl`, `--theme-radius-pill` |
| The depth | `--theme-shadow-xs` … `--theme-shadow-lg`, `--theme-shadow-focus` |
| The spacing | `--theme-space-1` … `--theme-space-8` |
| The type | `--theme-font-sans`, `--theme-font-mono`, the sizes, the line heights |
| The patterns | `--theme-pattern-geo`, `--theme-pattern-geo-position`, `--theme-pattern-geo-size` |

### How the palette is changed

```css
:root {
  --theme-primary: #7c3aed;          /* violet */
  --theme-primary-strong: #6d28d9;
  --theme-primary-soft: #f3e8ff;
}
```

That is all — the buttons, the links, the focus rings, the badges, the
headings of the sign in page and the pattern of the decorative panel follow
automatically.

### The dark theme

`theme/tokens.css` contains a second set of tokens under `.theme-dark`.
**Only the tokens are redefined** — therefore a component works in the dark
theme without a single additional line.

The switch is done by the server:

| | |
|---|---|
| the button | `app/views/shared/_theme_toggle.html.erb` — a form button (sun / moon) |
| the action | `POST /theme` (`ThemesController`) — stores the choice in a cookie |
| the reading | `ApplicationController#current_theme` — the cookie decides |
| the rendering | `<html class="theme-dark" data-bs-theme="dark">` |

`data-bs-theme` switches the components of the CSS framework, the class
`theme-dark` switches the tokens of the application.

Because the **server** reads the cookie and renders the page in the chosen
theme, there is no flash of the light theme while the page loads (a solution
with `localStorage` would paint the light theme first and switch it
afterwards).

---

## 2. The mapping onto Bootstrap (`theme/bootstrap-theme.css`)

Bootstrap 5.3 compiles most of its colours into literal values, so a theme
cannot simply set `--bs-primary`. This file maps the tokens onto the
variables of the components that the application uses:

* the buttons (`.btn-primary`, `.btn-secondary`, `.btn-outline-danger`, …)
* the forms (`.form-control`, `.form-select`, `.form-label`, `.form-check-input`)
* the cards, the tables, the badges, the alerts, the navbar and the dropdowns

**Rule:** no component of the application may hard code a colour. If a colour
is needed, it is either a token or a variable of the framework.

---

## 3. The components (`theme/components.css`)

The reusable parts of the interface:

| Class | What it is |
|---|---|
| `.brand`, `.brand-mark`, `.brand-title` | the logo and the wordmark (an inline SVG, no image) |
| `.app-navbar`, `.account-chip`, `.account-avatar` | the navigation header and the chip with the signed in account |
| `.dropdown-form`, `.dropdown-item-danger` | the dropdown of the profile - the sign out lives inside it |
| `.page-header`, `.page-title`, `.page-subtitle`, `.stat-pill` | the header of a page and the counters |
| `.table-card`, `.toolbar`, `.toolbar-filter`, `.toolbar-search`, `.toolbar-select` | the table with the toolbar above it and the filter inside the toolbar |
| `.checkbox-column`, `.table-sort-link`, `.cell-strong`, `.cell-sub` | the columns of the table |
| `.status`, `.status-dot`, `.is-blocked` | the status of an account and the dimmed row of a blocked account |
| `.activity-cell`, `.cell-line`, `.sparkline`, `.spark-bar` | the last activity with the small bar chart of the history |
| `.auth-field-control` | the wrapper of an input with its icons - IMPORTANT: the icons are centred in it, not in the whole field |
| `.assistant-card`, `.assistant-input`, `.assistant-answer`, `.assistant-plan` | the assistant |
| `.auth-shell`, `.auth-panel`, `.auth-art`, `.auth-field`, `.auth-submit` | the split screen of the sign in and the registration |
| `.filter-card`, `.empty-state`, `.app-footer` | the rest of the pages |

---

## 4. The patterns

The decorative geometric pattern of the sign in page is drawn with **pure CSS**
(no image, no animation):

```css
.auth-art::before {
  background-image: var(--theme-pattern-geo);
  background-position: var(--theme-pattern-geo-position);
  background-size: var(--theme-pattern-geo-size);
}
```

The pattern itself is a stack of linear gradients that form triangles. It is
sized and positioned with the tokens, therefore it can be made finer or
coarser without touching the component.

**IMPORTANT:** the pattern is only used on the sign in page. The area of the
table stays on a plain surface — the task asks for no wallpaper under the
table.

---

## 5. The audit of the user interface (the checklist)

The result of the review with the checklist of the ui-ux-pro-max skill:

| Check | Result |
|---|---|
| No emojis as icons | only Bootstrap Icons (one consistent set) and inline SVG for the brand |
| cursor-pointer on the clickable elements | the rows of the table, the buttons and the links |
| Hover states without a layout shift | only colours and borders change - never a scale |
| Contrast in the light theme | the muted text is `--theme-slate-600` (7.4:1), the subtle text `--theme-slate-500` (4.7:1) |
| Contrast in the dark theme | the same tokens, dark surfaces - the messages use their own text tokens |
| Focus states visible | every custom control has a `:focus-visible` ring (`--theme-shadow-focus`) |
| `prefers-reduced-motion` | every animation is switched off (and the rule is written down explicitly) |
| Responsive 375 / 768 / 1024 / 1440 | `script/responsive_check.rb` opens all four resolutions and proves that the page never scrolls sideways |
| Labels for the inputs | every input has a visible label - a placeholder is never the only label |
| The colour is not the only indicator | the status is a dot **and** a text, the blocked rows are struck through |
| Table on a small screen | the table scrolls inside its own container, the page does not |

## 6. The rules of the project

1. **No hard coded colours** in the components — only tokens.
2. **No animation.** `application.css` switches off every transition and every
   animation of the framework (`* { transition: none !important; animation: none !important; }`).
   The state of an element changes instantly.
3. **No browser alerts.** The status messages are Bootstrap alerts inside the
   page (`app/views/shared/_flash.html.erb`).
4. **The table area stays plain** — no background image, no gradient.
5. **Every new component** is built with the tokens, is documented in this
   file and is responsive (the table scrolls horizontally on a small screen,
   the decorative panel disappears below 992 px).

---

## 7. How a new component is added

1. Add the tokens that it needs to `theme/tokens.css` (only if they do not
   exist yet).
2. Write the component in `theme/components.css` — with the tokens, never with
   a literal colour.
3. Use it in the view and add a line to the table above.

Example — a new status colour:

```css
/* theme/tokens.css */
--theme-info: #0ea5e9;
--theme-info-soft: #e0f2fe;

/* theme/components.css */
.badge.text-bg-info {
  background-color: var(--theme-info-soft) !important;
  color: var(--theme-info) !important;
}
```
