# Korvexa — UI Design Brief

> **Paste this whole document into your AI UI tool** (v0, Lovable, Bolt, Figma
> AI, etc.). It fully specifies the product, screens, states, data, flows, and a
> complete design system. Build a **modern, responsive web app**. You may build
> with mock data first; a real REST API contract is included at the end so the UI
> can be wired up later without redesigning anything.

---

## 1. Product in one paragraph

**Korvexa** is a self-hostable, Jira-style **task manager** for individuals and
small teams. Users work inside a **workspace** that contains **projects**; each
project has **tasks** on a **Kanban board** (To Do → In Progress → Done). Tasks
have priority, due dates, assignees, labels, comments, and an activity history.
Teams add members with roles, assign work, and get in-app notifications. Think
**Linear / Height / Asana**-caliber polish: fast, calm, keyboard-friendly,
information-dense but never cluttered.

**Target users:** solo makers who want a private board, and small teams (2–10)
who want shared projects, assignments, and notifications.

## 2. Design direction (the vibe)

Aim for a **premium, minimal, productivity-tool aesthetic**:

- **Calm and focused.** Generous whitespace, restrained color, content-first.
  Color is used for meaning (status/priority/labels), not decoration.
- **Crisp and fast-feeling.** Subtle motion (120–180ms), snappy hovers, optimistic
  updates on the board. Nothing bouncy or playful.
- **Dense but legible.** Comfortable on a laptop showing three board columns at
  once; gracefully collapses on mobile.
- **Light and dark mode**, both first-class. Dark mode is not an afterthought —
  many power users live in it.
- **Reference feel:** Linear (typography, keyboard, speed), Height (board polish),
  Vercel/Geist (neutral surfaces), Notion (calm forms). Avoid heavy shadows,
  gradients-for-their-own-sake, or cartoonish illustrations.

## 3. Design system

### 3.1 Color

Use a **neutral gray foundation** + a single **brand accent** (indigo/violet) +
**semantic colors** for status and priority. Provide both themes.

**Neutrals (light mode)**
- App background: `#F7F8FA`
- Surface / card: `#FFFFFF`
- Border / divider: `#E7E9EE`
- Text primary: `#1A1D23`
- Text secondary: `#5B616E`
- Text muted: `#8A909C`

**Neutrals (dark mode)**
- App background: `#0E0F12`
- Surface / card: `#17181C`
- Elevated surface: `#1E2026`
- Border / divider: `#2A2D34`
- Text primary: `#ECEDEF`
- Text secondary: `#A6ABB5`
- Text muted: `#6E747F`

**Brand accent (interactive: buttons, focus, links, active nav)**
- Accent: `#6366F1` (indigo-500)
- Accent hover: `#4F46E5`
- Accent subtle bg: `rgba(99,102,241,0.10)`
- Focus ring: `#6366F1` at 40% + 2px offset

**Semantic — task status** (used for column headers, dots, chips)
- To Do → slate/gray `#94A3B8`
- In Progress → amber `#F59E0B`
- Done → green `#22C55E`

**Semantic — task priority** (small dot on cards, dropdowns)
- Low → blue-gray `#64748B`
- Medium → orange `#F97316`
- High → red `#EF4444`

**Feedback**
- Success `#22C55E` · Warning `#F59E0B` · Error/destructive `#EF4444` · Info `#3B82F6`
- Overdue due-dates render in **error red**.

**Labels** carry their own color (a hex string from the data). Render label chips
as a soft tinted background (`color @ ~15% alpha`) with the color as a leading dot
and readable text — never full-saturation fills behind text.

### 3.2 Typography

- **Font:** Inter (or the tool's closest system-UI sans). Tabular numbers for IDs
  and counts.
- **Scale:** Display 28/700 · H1 22/650 · H2 18/600 · Body 14/450 · Small 13/450 ·
  Caption 12/500 (labels, meta). Line-height ~1.5 for body.
- Task keys (e.g. `ACME-42`), counts, and dates use a slightly muted, medium-weight
  treatment. Keys may use a monospaced accent if it reads cleanly.

### 3.3 Spacing, radius, elevation

- **Spacing scale:** 4, 8, 12, 16, 24, 32, 48. Cards use 12–16 internal padding.
- **Radius:** inputs/buttons/cards 8px; chips/pills 6px; modals 12px; avatars full.
- **Elevation:** flat by default; use a 1px border for separation. Only elevate
  transient surfaces (dropdowns, popovers, dragged card, modals) with a soft
  shadow (`0 4px 16px rgba(0,0,0,.08)` light / stronger, lower-alpha in dark).

### 3.4 Core components to define

Buttons (primary/secondary/ghost/destructive/icon), Input, Textarea, Select/
Dropdown, Combobox (assignee/label picker), Checkbox, Toggle/Switch, Segmented
control, Chip/Tag (removable + filter variants), Avatar + AvatarStack, Badge
(count), Tooltip, Popover, Modal/Dialog, Toast/Snackbar, Tabs, Kanban column,
Task card, Empty state, Skeleton loader, Inline banner (error), Pagination.

### 3.5 Universal states (every data view must handle all four)

1. **Loading** — skeletons that match the final layout (not spinners where a
   skeleton fits). Board shows 2–3 ghost cards per column.
2. **Empty** — a friendly, centered illustration-lite state with a one-line
   explanation and a primary action (e.g. "No projects yet — Create your first
   project").
3. **Error** — an inline banner with the message and a Retry; never a blank screen.
   (The API returns human messages in a `detail` field.)
4. **Populated** — the normal state.

### 3.6 Accessibility & interaction rules

- WCAG AA contrast in both themes. Don't encode meaning in color alone — pair
  status/priority color with a label or icon.
- Full keyboard support: `Tab` order, visible focus ring, `Esc` closes overlays,
  `Enter` submits forms. A command-style **quick actions** affordance is a plus.
- Drag-and-drop must have a non-drag fallback (a status dropdown on the card /
  detail view) for keyboard and touch users.
- Respect `prefers-reduced-motion`.

---

## 4. Information architecture & navigation

```
Auth (logged out)
  └─ Login  ⇄  Register

App shell (logged in) — persistent top bar + left/bottom nav
  Top bar:  [Workspace switcher ▾]        [🔍 search]     [🔔 notifications •]  [avatar ▾]
  Primary nav:  Projects | My Tasks
  Account menu (avatar): email, Members, Settings(optional), Log out

  Projects  ── Project board (Kanban) ── Task detail (drawer/modal or page)
  My Tasks  ── (same Task detail)
  Notifications (panel or page) ── deep-links to Task detail
  Members (workspace) ── invite / roles
```

- **App shell** is persistent: workspace switcher (left of top bar), global
  search, notification bell with unread badge, account menu. Primary navigation
  between **Projects** and **My Tasks**.
- On desktop, prefer a **left sidebar** for primary nav + workspace switcher; on
  mobile, collapse to a **bottom tab bar** (Projects, My Tasks) with the bell and
  account in the top bar.
- **Task detail** should open as a **right-hand drawer** on desktop (board stays
  visible behind it) and a **full page** on mobile.

---

## 5. Screens (build all of these)

For every screen, implement the four universal states from §3.5.

### 5.1 Login
- Centered card (max ~400px). Fields: **Email**, **Password**. Primary **"Log in"**
  button (full-width). Link: **"Don't have an account? Register."**
- Inline error above the form on bad credentials ("Invalid email or password").
- Brand wordmark **Korvexa** above the card.

### 5.2 Register
- Same centered card. Fields: **Name**, **Email**, **Password** (helper: "At least
  8 characters"). Primary **"Register"**. Link back to Login.
- Client-side validation; show field errors. On success, go straight into the app.

### 5.3 App shell (wraps everything below)
- **Top bar** left→right: **Workspace switcher** (shows current workspace name +
  chevron; menu lists the user's workspaces with a check on the active one, plus
  **"+ New workspace"**), global **search**, **notification bell** (badge with
  unread count), **avatar menu** (current email shown disabled, **Members**,
  **Log out**).
- Switching workspace reloads all workspace-scoped content (projects, my tasks,
  labels, notifications).

### 5.4 Projects list
- A responsive **grid or list of project cards**. Each card shows:
  - a colored **key avatar** (first letter of the key, tinted by project color),
  - **project name**,
  - **`KEY`** and an **open/total task count** (e.g. `ACME · 3/8 open`),
  - an **archived** tag if archived,
  - a **⋯ menu**: Archive / Unarchive / Delete (Delete is destructive + owner-only;
    hide it for non-owners).
- Header row: title **Projects**, a **"Show archived"** toggle, and a primary
  **"+ New project"** button (also the FAB on mobile).
- **Create project** dialog: **Name** (required), **Key** (optional, uppercase,
  helper "Auto-derived from the name if left blank"), optional color. Show the
  auto-derived key as a live preview when the key field is empty.
- **Delete** asks for confirmation and warns it removes all the project's tasks.
- Tapping a card opens its **board**.

### 5.5 Project board (Kanban) — the hero screen
The most important screen; invest the most polish here.

- **Board header:** project name + `KEY`, and a **filter bar**:
  - a **search** input (filters by task title/description),
  - **Priority** filter (Any / High / Medium / Low),
  - **Due** filter (Any / Overdue / Due today / Due this week),
  - **Label** filter chips (multi-select look; here single active label is fine)
    with a **"+ Label"** action to create a workspace label inline,
  - a **"Clear filters"** control that appears only when filters are active.
- **Three columns:** **To Do**, **In Progress**, **Done**. Each column header shows
  the **name + count** and a **"+"** to add a task to that column. Color-tint the
  column header/dot by status (§3.1).
- **Task cards** (see §6 for card anatomy). Cards are **draggable**:
  - **Drop on another column** → moves the task there (appends to the end).
  - **Drop onto a specific card** → inserts immediately **before** that card
    (reorder within a column, or move-and-position across columns). Show an
    **insertion line** where it will land.
  - Provide a **non-drag fallback**: a status control on the card menu / detail.
- **Add task (quick)**: the column "+" opens a lightweight inline composer (just a
  title field, `Enter` to create); the card appears immediately.
- **Optimistic updates:** reflect moves instantly, reconcile with the server, and
  gently roll back on failure with a toast.
- **Empty column** shows a faint "Drop tasks here" affordance.

Desktop layout sketch:
```
┌───────────────────────────────────────────────────────────────────────┐
│  Acme Web App  (WEB)        🔍[ search ]  Priority▾  Due▾  ▢bug ▢urgent +Label │
├───────────────┬───────────────────────┬───────────────────────────────┤
│ To Do    (3) +│ In Progress   (2)   + │ Done            (5)          + │
│ ┌───────────┐ │ ┌───────────┐         │ ┌───────────┐                  │
│ │ • WEB-14  │ │ │ • WEB-9   │         │ │ ✓ WEB-2   │                  │
│ │ Fix nav…  │ │ │ Design…   │         │ │ CI setup  │                  │
│ │ 🔴 Aug 1  │ │ │ 🟠 @bob   │         │ │           │                  │
│ │ [bug]     │ │ │ [feature] │         │ │           │                  │
│ └───────────┘ │ └───────────┘         │ └───────────┘                  │
└───────────────┴───────────────────────┴───────────────────────────────┘
```

### 5.6 Task detail (drawer on desktop, page on mobile)
Two tabs: **Details** and **Activity**.

**Details tab**
- **Header:** task key (`ACME-42`), a delete (trash) action, and close.
- **Title** (inline-editable text).
- **Description** (multiline; consider light markdown rendering).
- **Row of fields** (selects): **Status** (To Do / In Progress / Done),
  **Priority** (Low / Medium / High with the priority color dot), **Assignee**
  (searchable member picker; "Unassigned" default), **Due date** (date picker with
  a Clear).
- **Labels:** current chips + an **Edit** control opening a multi-select of the
  workspace's labels.
- **Save** button (primary). Saving persists all changed fields at once.
- **Comments** section below: a list of comments (author name, avatar, relative
  timestamp, body) newest-appended; each of the **current user's own** comments has
  edit/delete. A composer at the bottom (textarea + Send). Support **@mentions**
  (typing `@` suggests workspace members; mentioning notifies them).

**Activity tab**
- A vertical **timeline**, newest first, of events: "**created** this task",
  "changed **status** from To Do to In Progress", "changed **priority** to High",
  etc., each with a relative timestamp and (when known) the actor.

### 5.7 My Tasks
- A cross-project list of the user's open work.
- Controls: a **segmented control** — **Today / This Week / All Open** — and an
  **"Assigned to me only"** toggle (on by default).
- Each row: priority dot, **title**, **project name + task key**, and a **due
  date** (red if overdue). Tapping opens Task detail.
- Sorted by due date then priority. Empty state: "Nothing here. Nice work!"

### 5.8 Members (workspace)
- List of members: avatar, **name**, **email**, **role** badge (Owner / Member).
- **Owner-only** controls (hidden for members): an **"Invite"** action (email +
  role) and a per-member **⋯ menu**: Make owner / Make member / Remove. An owner
  cannot remove themselves (disable it).
- Invite dialog: **Email** + **Role** select. Show a success toast; a pending/
  invited state is fine if the person hasn't registered yet.

### 5.9 Notifications
- A **panel** (opened from the bell) or full page. List newest-first; **unread**
  items are visually distinct (bolder + an accent dot).
- Each item: an icon by type (**assigned** = person/assignment icon; **mention** =
  `@` icon), the **message** (e.g. *"Alice assigned you 'Ship it'"*), and a
  relative timestamp.
- A **"Mark all read"** action. Clicking an item marks it read and **deep-links to
  the related task's detail**.
- The bell badge shows the unread count and clears as items are read.

### 5.10 New workspace (small dialog)
- Single **Name** field + Create. On success, switch into the new workspace.

---

## 6. Component anatomy — the Task Card (get this right)

The card is the atom of the product. Keep it compact but scannable:

```
┌─────────────────────────────┐
│ ● ACME-42                    │   ● = priority dot (color by priority)
│ Fix mobile nav overflow      │   title (max 2 lines, then ellipsis)
│ [bug] [urgent]               │   label chips (tinted), wrap to 1–2 lines
│ 📅 Aug 1        (A) Bob       │   due date (red if overdue) · assignee avatar+name
└─────────────────────────────┘
```

- **Priority dot** leads the key row (color = priority).
- **Task key** (`ACME-42`) muted, medium weight.
- **Title**: 1–2 lines, ellipsis after.
- **Labels**: soft tinted chips; hide overflow beyond ~3 with a `+N`.
- **Due date**: small, with a calendar glyph; **red + bold when overdue** (past
  due and not Done).
- **Assignee**: small avatar (initials) + optional name; omit entirely if
  unassigned.
- **Hover**: subtle lift/border-accent; reveal a `⋯` for quick actions.
- **Dragging**: elevate with shadow, ~90% opacity ghost left behind.

---

## 7. Data model (what to render)

Field names below match the API. Enums are fixed — use exactly these values.

- **User:** `id`, `email`, `name`.
- **Workspace:** `id`, `name`, `owner_id`, `role` (`owner` | `member` — the current
  user's role here).
- **Member:** `user_id`, `email`, `name`, `role`.
- **Project:** `id`, `name`, `key` (short uppercase, e.g. `ACME`), `description`,
  `color` (hex), `archived` (bool), `open_tasks` (int), `total_tasks` (int).
- **Task:** `id`, `project_id`, `number` (int), `key` (e.g. `ACME-42`), `title`,
  `description`, `status` (`todo` | `in_progress` | `done`), `priority` (`low` |
  `medium` | `high`), `assignee_id` (nullable), `due_date` (date, nullable),
  `position` (float — ordering; you rarely display it), `labels` (array of Label).
- **Label:** `id`, `name`, `color` (hex).
- **Comment:** `id`, `task_id`, `author_id`, `author_name`, `body`, `created_at`,
  `updated_at`.
- **Activity:** `id`, `task_id`, `actor_id`, `action` (`created` | `status_changed`
  | `updated`), `field`, `old_value`, `new_value`, `created_at`.
- **Notification:** `id`, `type` (`assigned` | `mention`), `task_id`, `message`,
  `read` (bool), `created_at`.

**Display mappings**
- Status labels: `todo` → "To Do", `in_progress` → "In Progress", `done` → "Done".
- Priority labels: `low` → "Low", `medium` → "Medium", `high` → "High".
- Task key = `{project.key}-{task.number}` (already provided as `key`).
- "Overdue" = `due_date` is in the past **and** status ≠ `done`.

---

## 8. Key user flows (wire these end-to-end)

1. **Onboard:** Register → land on Projects (empty) → Create first project → open
   board → add a task via a column "+".
2. **Move work:** Drag a card To Do → In Progress → Done; counts on the project
   card and column headers update.
3. **Reorder:** Drag a card onto another card in the same column; order persists.
4. **Detail edit:** Open a card → change status/priority/assignee/due/labels →
   Save → board reflects it. Add a comment with an `@mention`.
5. **My Tasks:** Switch to My Tasks → toggle Today/Week/All and "Assigned to me" →
   open a task from there.
6. **Team:** Open Members → Invite by email with a role → (as owner) promote/remove.
7. **Notifications:** Get assigned/mentioned → bell badge increments → open panel →
   click → land on the task → badge decrements.
8. **Workspace switch:** Use the switcher → create a second workspace → content
   swaps entirely.

---

## 9. Responsive behavior

- **≥1200px (desktop):** left sidebar (workspace switcher + Projects/My Tasks),
  3-column board side by side, task detail as a right drawer (~440px).
- **768–1199px (tablet):** collapsible sidebar; board columns may scroll
  horizontally; detail as a wider drawer or modal.
- **<768px (mobile):** top bar (workspace + bell + avatar) + **bottom tab bar**
  (Projects, My Tasks); board columns become **horizontally swipeable** one-at-a-
  time or a status-segmented single column; task detail is a **full page**; FABs
  for primary create actions.

---

## 10. Micro-interactions & polish checklist

- Optimistic board moves with graceful rollback + toast on failure.
- Insertion-line indicator while dragging; column highlights on valid hover.
- Skeleton loaders shaped like the real content.
- Toasts for create/save/delete/invite (success + error), auto-dismiss.
- Relative timestamps ("2h ago") with an absolute tooltip on hover.
- Unread notification badge animates the count change subtly.
- Empty states everywhere, each with one clear next action.
- Keyboard: `Esc` closes drawers/modals; `Enter` submits; focus rings visible.
- Dark/light toggle in the account menu; remember the choice.

---

## 11. (Optional) Live API contract

The UI can be built with mock data. To make it real, it talks to a REST API
(JSON). Auth is a **bearer access token** plus an **`X-Workspace-Id`** header that
selects the active workspace; a `401` should trigger a token refresh then retry,
and otherwise send the user to login. Errors come back as
`{ "detail": "<message>", "request_id": "<id>" }` — surface `detail` in toasts/
banners. List endpoints that paginate return `{ items, total, limit, offset }`.

**Auth & workspace**
- `POST /auth/register` `{email,name,password}` → `{access_token, refresh_token}`
- `POST /auth/login` `{email,password}` → tokens
- `POST /auth/refresh` `{refresh_token}` → new tokens
- `GET /auth/me` → current user
- `GET /workspaces` → your workspaces (+ your `role`)
- `POST /workspaces` `{name}` → create
- `GET /workspaces/{id}/members` · `POST /workspaces/{id}/invite` `{email,role}` ·
  `PATCH /workspaces/{id}/members/{userId}` `{role}` ·
  `DELETE /workspaces/{id}/members/{userId}`

**Projects**
- `GET /projects?include_archived=` · `POST /projects` `{name,key?,description?,color?}`
- `GET /projects/{id}` · `PATCH /projects/{id}` · `DELETE /projects/{id}` (owner)
- `POST /projects/{id}/archive` · `POST /projects/{id}/unarchive`

**Tasks & board**
- `GET /projects/{id}/board?q&priority&label_id&due` → `{todo:[],in_progress:[],done:[]}`
- `GET /projects/{id}/tasks?q&status&priority&label_id&due&limit&offset` → page
- `POST /projects/{id}/tasks` `{title,description?,status?,priority?,assignee_id?,due_date?,label_ids?}`
- `GET /tasks/{id}` · `PATCH /tasks/{id}` (any of the task fields) · `DELETE /tasks/{id}`
- `POST /tasks/{id}/reorder` `{position}` or `{before_id, after_id}`
- `PUT /tasks/{id}/labels` `[labelId, …]`

**Collaboration**
- `GET /tasks/{id}/comments` (page) · `POST /tasks/{id}/comments` `{body}` ·
  `PATCH /comments/{id}` `{body}` · `DELETE /comments/{id}`
- `GET /tasks/{id}/activity`
- `GET /labels` · `POST /labels` `{name,color?}` · `PATCH /labels/{id}` · `DELETE /labels/{id}`
- `GET /me/upcoming?window=today|week|all&mine=true|false`
- `GET /notifications?unread_only=` · `GET /notifications/unread_count` ·
  `POST /notifications/{id}/read` · `POST /notifications/read_all`

---

## 12. Deliverables to generate

1. A complete **design system / component library** (§3) in light + dark.
2. All **screens** in §5 with the four states each (§3.5).
3. The **Kanban board** with drag-and-drop, filters, and the task card (§5.5, §6).
4. The **task detail** drawer with Details/Activity tabs, comments, @mentions (§5.6).
5. Responsive layouts for desktop / tablet / mobile (§9).
6. Wired **navigation** and the flows in §8 (mock data is fine).

**North star:** it should feel like a tool a developer would happily use every
day — as fast and clean as Linear, as clear as Asana, with zero visual clutter.
