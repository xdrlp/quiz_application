# Quiz Guard - UI Wireframes (Condensed)

Flutter quiz app with Firebase. **Theme:** Light (white-grey gradient), red accents (#FF3B30), gradient input fields.

---

## SCREENS

### 1. SPLASH SCREEN
Center: Quiz icon (64x64), title, loading spinner. Auto-routes to login or home.

### 2. STARTER SCREEN  
BG: White→grey gradient. Logo (140x140), "Quiz Guard" title, "Honest learning, real results" subtitle, red monitoring bullet. Buttons: [Login Image] [Sign Up Image]. Footer info link. Bug report icon (top-right).

### 3. LOGIN SCREEN
BG: Light grey. Back button (top-left). Title: "Hello, Welcome Back" (48px bold). 
- Email field (60px, gradient border, email icon)
- Password field (60px, gradient, eye toggle)
- "Forgot password?" link → Reset dialog
- [Red Login Button] → Firebase auth
- "Sign up" link

**Reset Password Dialog:** Backdrop blur, lock icon, email input, [Reset] [Cancel] buttons.

### 4. SIGN UP SCREEN
BG: Image overlay. Back button. Title: "Let's get started!" (32px bold).
5 fields (60px each, gradient borders):
- First Name, Last Name, Email, Password, Confirm Password
- [Create Account Button] (red) or spinner if loading
- "Login here" link (red, bold)

### 5. HOME SCREEN
BG: White-grey gradient. Header: [👤] "Quiz Application" [⚙️].
Greeting: "Hello, [Name]" (32px), subtitle "What would you like to do today?"

**2x2 Grid (Neumorphic cards):**
1. Create Quiz (add icon) → /create_quiz
2. Take Quiz (GPS icon) → dialog
3. Quiz board (book icon) → /my_quizzes  
4. Quiz Taken (history icon) → /quiz_history

**Recent Activity:** Dark grey cards, title + timestamp + [View Details] button (max 5 items).

### 6. CREATE QUIZ SCREEN
BG: White-grey. Back button. Centered title: "New Quiz Details". Form (neumorphic container):
- Title input (required)
- Description input (optional)
- Time limit (default 10 min, numeric)
- [Continue] button → Creates quiz, navigates to /edit_quiz

### 7. EDIT QUIZ SCREEN
Header: [<] [Quiz Title] [Publish/Unpublish] (red if published, grey if draft).
**Question List:** Title, type + points, [Edit] [Delete] buttons per question.
**Settings Panel (collapsible):** Shuffle toggles, time input, password protection.
**FAB:** [+ Add Question] (green, bottom-right).

### 8. QUESTION EDITOR DIALOG
Title: "Add/Edit Question" [X].
- Dropdown: Question type (Multiple Choice, True/False, Short Answer, Paragraph)
- Text field: Question prompt (required)
- Selector: Points (default 1)
- Answer options: Checkboxes to mark correct
- [+ Add Option] [Remove Last] buttons
- [Cancel] [Save Question] actions

### 9. TAKE QUIZ DIALOG (2 steps)
**Step 1:**
- Title: "Enter Quiz Code"
- Code input field + [Paste 📋] button
- [Close] [Take Quiz] buttons

**Step 2 (after found):**
- Quiz title, description, questions count, author name
- [Close] [Attempt Quiz] buttons

### 10. TAKE QUIZ PAGE
Header: "Quiz: [Title]" ⏱ Timer (MM:SS) [☰ Menu]
- "Question X of Y" text
- Question display (text)
- Answer options (radio/checkbox/text based on type)
- Controls: [❤ Flag] [< Previous] [Next >]
- **Question Navigator:** Grid showing Q1-Q10 with status (■=answered, □=unanswered, ☐=flagged)
- [Submit Quiz] button

### 11. MY QUIZZES SCREEN
Back button. Title: "My Quizzes". Multi-select icons (appear on selection).
- Sort dropdown (Updated, Name, Created)
- Filter dropdown (All, Recent, Incomplete, Popular)
- Search field

**Quiz List (grouped by status):**
- PUBLISHED (count), DRAFTS (count)
- Each: Checkbox, title, code [📋 Copy], date, questions + status
- [Edit] [Analyze] [...] buttons
- FAB shows count when selected: "[✓ X selected]"

### 12. PROFILE SCREEN
Back button. Title: "Profile" [Edit/Save] toggle (top).
- Email display (read-only)
- Form (edit mode): First Name, Last Name, Class/Section
- **Stats:** Quizzes Created, Quizzes Taken, Avg Score (display only)
- Links: [Change Password] [Privacy Settings] [Report Issue] [Logout]

### 13. QUIZ HISTORY SCREEN
Back button. Filter dropdown, search field.
**Attempt Cards:** Quiz title, "Attempt #X | Score: Y/100", completion date, [Review] button.
[Load More] at bottom.

### 14. QUIZ ANALYSIS SCREEN (3 Tabs)
**Tab 1 - Summary:** Quiz title + code, stats (avg, min, max, median), score distribution chart, question performance bars.

**Tab 2 - Insights:** Difficult questions (below avg %), easy questions (above avg %), avg time/question, violation count, most flagged questions.

**Tab 3 - Individual:** Student dropdown selector, attempt details (score, time, date, status), answer-by-answer review (✓/✗ with correct answer), violations timeline, [Edit Time] [Recalculate] [Save] buttons.

---

## COLOR PALETTE

| Element | Color |
|---------|-------|
| Background | White → Grey (#9B9B9B) gradient |
| Primary Text | Dark grey (#4A4A4A, #2C3E50) |
| Secondary Text | Light grey (#7F8C8D) |
| Input Border | Gradient (black → white) |
| Input BG | Transparent |
| Accent | Red (#FF3B30, #E94057) |
| Card BG | Light grey (#F5F5F5) |
| Dark Card BG | Grey (#6E6E6E) |
| Button (Publish) | Dark grey (#2C3E50) |
| Button (Unpublish) | Dark red (#C0392B) |
| FAB | Green (#27AE60) |

---

## KEY COMPONENTS

**Gradient Input Fields:** 2px gradient stroke (black→grey→white), 12px radius, 60px height, icon + placeholder text, visibility toggle for passwords.

**Neumorphic Cards:** Outer gradient border (white top-left to black bottom-right), inner gradient fill (grey→white), 20px radius, inset shadow effect.

**Header Gradient:** Light grey background with layered gradient (dark grey underline).

---

## NAVIGATION FLOW

```
SPLASH → Check Auth
  ├→ YES → HOME
  │   ├→ [Profile icon] → PROFILE
  │   ├→ [Create] → CREATE → EDIT
  │   ├→ [Take] → TAKE QUIZ DIALOG → TAKE PAGE
  │   ├→ [Board] → MY QUIZZES
  │   │   ├→ [Edit] → EDIT QUIZ
  │   │   ├→ [Analyze] → ANALYSIS
  │   │   └→ [Delete] → Undo
  │   └→ [History] → QUIZ HISTORY → ANALYSIS
  │
  └→ NO → STARTER
      ├→ [Login] → LOGIN
      │   ├→ [Forgot] → Reset Dialog
      │   └→ [Sign up] → SIGNUP
      └→ [Sign Up] → SIGNUP
          └→ [Login] → LOGIN

GLOBAL: Bug report dialog on Starter/Login/Signup (modal)
```

---

## RESPONSIVE DESIGN
- Mobile: Full width, portrait (login/signup locked to portrait)
- Tablet: ConstrainedBox max 600-900px width
- Auto-scroll inputs to focused field on keyboard show

---

**Total Screens:** 14  
**Auth:** Firebase (email/password)  
**Database:** Firestore (quizzes, questions, attempts, users, violations)  
**Key Feature:** Real-time anti-cheat monitoring (app state, screen size, accessibility service detection)
