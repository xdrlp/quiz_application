    # Quiz Guard - Application Wireframes (Accurate)

    Based on actual codebase analysis. All screens documented with precise UI layout, colors, and functionality.

    ---

    ## TABLE OF CONTENTS

    1. [Splash Screen](#splash-screen)
    2. [Starter Screen](#starter-screen)
    3. [Login Screen](#login-screen)
    4. [Sign Up Screen](#sign-up-screen)
    5. [Home Screen](#home-screen)
    6. [Take Quiz Dialog](#take-quiz-dialog)
    7. [Create Quiz Screen](#create-quiz-screen)
    8. [Edit Quiz Screen](#edit-quiz-screen)
    9. [Question Editor Dialog](#question-editor-dialog)
    10. [My Quizzes Screen](#my-quizzes-screen)
    11. [Profile Screen](#profile-screen)
    12. [Quiz History Screen](#quiz-history-screen)
    13. [Take Quiz Page](#take-quiz-page)
    14. [Quiz Analysis Screen](#quiz-analysis-screen)
    15. [Navigation Flow](#navigation-flow)

    ---

    ## SPLASH SCREEN

    **File:** `lib/screens/splash_screen.dart`  
    **Route:** `/` (initial)  
    **Transition:** Automatic auth check → `/login` or `/home`

    ### Layout:
    ```
    ┌──────────────────────────────┐
    │                              │
    │                              │
    │      🎯 (Quiz Icon)          │
    │      64x64 size              │
    │                              │
    │   Quiz Application           │
    │   (centered title)           │
    │                              │
    │   ◐ (Loading Spinner)        │
    │                              │
    │                              │
    │                              │
    └──────────────────────────────┘
    ```

    ### Features:
    - Simple centered layout
    - 1-second delay before auth check
    - Auto-routes based on `AuthProvider.isAuthenticated`

    ---

    ## STARTER SCREEN

    **File:** `lib/screens/starter_screen.dart`  
    **Route:** `/starter` (if not authenticated)  
    **Purpose:** Welcome landing page with app branding

    ### Theme:
    - **Background:** Linear gradient white → gray (#9b9b9b)
    - **Primary Color:** Dark grey (#4A4A4A)
    - **Accent Color:** Red (#FF3B30)

    ### Layout:
    ```
    ┌────────────────────────────────────┐
    │                         [🐛 Bug]   │ (Report bug icon, top-right)
    ├────────────────────────────────────┤
    │                                    │
    │      📄 (Logo Image 140x140)       │ (assets/images/logo.png)
    │                                    │
    │          Quiz Guard                │ (Title, 32px, bold)
    │                                    │
    │   Honest learning, real results    │ (Subtitle, 16px, underlined)
    │                                    │
    │   ● Real-time monitoring           │ (Bullet with red dot)
    │                                    │
    │                                    │ (100px gap)
    │                                    │
    │   ┌──────────────────────────┐    │
    │   │ [Login Button Image]     │    │ (assets/images/logIn_button.png)
    │   └──────────────────────────┘    │
    │                                    │
    │              or                    │
    │                                    │
    │   ┌──────────────────────────┐    │
    │   │ [Sign Up Button Image]   │    │ (assets/images/signUp_button.png)
    │   └──────────────────────────┘    │
    │                                    │
    │  ℹ️ Learn more about Quiz Guard    │ (Footer link)
    │                                    │
    └────────────────────────────────────┘
    ```

    ### Features:
    - App branding with logo and tagline
    - Feature highlight bullet point
    - Button navigation via image assets
    - Report bug dialog (top-right)
    - Footer info link
    - Responsive design (handles wide screens)

    ### Navigation:
    - **[Login Button]** → `/login`
    - **[Sign Up Button]** → `/signup`
    - **[🐛]** → Report Bug Dialog

    ---

    ## LOGIN SCREEN

    **File:** `lib/screens/login_screen.dart`  
    **Route:** `/login`  
    **Purpose:** User email/password authentication

    ### Theme:
    - **Background:** Light grey (#F5F5F5)
    - **Text Color:** Black (#000000) / Grey (#424242)
    - **Input Border:** Gradient (black → white)

    ### Layout:
    ```
    ┌────────────────────────────────────┐
    │ [<]                                │ (Back button, top-left)
    │                                    │
    │                                    │
    │   Hello,                           │ (48px, bold, CanvaSans)
    │   Welcome                          │
    │   Back                             │
    │                                    │
    │                                    │ (60px gap)
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ ✉️  Email         [gradient] │ │ (60px height, gradient border)
    │   └─────────────────────────────┘ │
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ 🔒  Password   [👁 Toggle]  │ │ (60px height, gradient border)
    │   └─────────────────────────────┘ │
    │                                    │
    │                  Forgot password?  │ (Right-aligned link)
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ [Red Login Button Image]    │ │ (assets/images/red_login_button.png)
    │   └─────────────────────────────┘ │
    │                                    │
    │   Don't have an account? Sign up  │ (Center-aligned link)
    │                                    │
    └────────────────────────────────────┘
    ```

    ### Input Fields:
    - **Email Field:**
    - Placeholder: "Email"
    - Icon: Email outline
    - Gradient border (black → grey → white)
    - Height: 60px

    - **Password Field:**
    - Placeholder: "Password"
    - Icon: Lock outline
    - Visibility toggle (eye icon)
    - Gradient border
    - Height: 60px

    ### Features:
    - Portrait orientation only
    - Keyboard handling with auto-scroll to focused field
    - Toast notifications for errors
    - Email validation regex
    - Password visibility toggle
    - Forgot Password dialog (custom styled)

    ### Forgot Password Dialog:
    ```
    ┌────────────────────────────────────┐
    │  Reset Password            [Blur]  │ (Backdrop blur effect)
    ├────────────────────────────────────┤
    │                                    │
    │        🔒 (Lock icon circle)       │
    │                                    │
    │      Reset Password                │ (20px bold)
    │  Enter your email to reset         │ (14px grey)
    │  your password                     │
    │                                    │
    │ ─────────────────────────────────  │ (Dashed line)
    │                                    │
    │ Email Address *                    │ (Label with red asterisk)
    │ ┌─────────────────────────────┐   │
    │ │ ✉️  Email                  │   │ (Gradient input field)
    │ └─────────────────────────────┘   │
    │                                    │
    │  ┌─────────────────────────────┐  │
    │  │  Reset password             │  │ (Grey gradient button)
    │  └─────────────────────────────┘  │
    │                                    │
    │  ┌─────────────────────────────┐  │
    │  │  Cancel                     │  │ (Red gradient button)
    │  └─────────────────────────────┘  │
    │                                    │
    └────────────────────────────────────┘
    ```

    ### Navigation:
    - **[< Back]** → Pop to previous screen
    - **[Forgot password?]** → Show Reset Password dialog
    - **[Sign up]** → `/signup`
    - **[Login Button]** → Authenticate & navigate

    ---

    ## SIGN UP SCREEN

    **File:** `lib/screens/signup_screen.dart`  
    **Route:** `/signup`  
    **Purpose:** New user account creation

    ### Theme:
    - **Background:** Image (assets/images/background.png) with black scaffold
    - **Text Color:** Black (#000000) / Grey (#000000, 54% opacity)
    - **Input Border:** Gradient (black → white)
    - **Button Color:** Red accent

    ### Layout:
    ```
    ┌────────────────────────────────────┐
    │ [< Back]                           │ (Top-left back button)
    │                                    │
    │                                    │
    │   Let's get started!               │ (32px, bold, MuseoModerno)
    │   Create an account to get         │ (16px, grey)
    │   all features                     │
    │                                    │
    │                                    │ (40px gap)
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ 👤  First Name    [gradient] │ │ (60px height)
    │   └─────────────────────────────┘ │
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ 👤  Last Name     [gradient] │ │
    │   └─────────────────────────────┘ │
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ ✉️  Email         [gradient] │ │
    │   └─────────────────────────────┘ │
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ 🔒  Password   [👁 Toggle]  │ │
    │   └─────────────────────────────┘ │
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ 🔒  Confirm Pwd [👁 Toggle] │ │
    │   └─────────────────────────────┘ │
    │                                    │
    │                                    │ (40px gap)
    │                                    │
    │   ┌─────────────────────────────┐ │
    │   │ [Create Account Button Img] │ │ (assets/images/create_account_button.png)
    │   └─────────────────────────────┘ │ (or loading spinner if _isCreatingAccount)
    │                                    │
    │   Already have an account?         │
    │   Login here                       │ (Red color, bold)
    │                                    │
    └────────────────────────────────────┘
    ```

    ### Input Fields (All 60px height):
    - First Name (person icon)
    - Last Name (person icon)
    - Email (email icon)
    - Password (lock icon + visibility toggle)
    - Confirm Password (lock icon + visibility toggle)

    ### Validations:
    - All fields required
    - Password minimum 6 characters
    - Passwords must match
    - Shows SnackBar with validation errors

    ### Loading State:
    - Button converts to circular progress indicator during signup
    - Button disabled while creating account

    ### Navigation:
    - **[< Back]** → `/signup` (closes screen)
    - **[Create Account]** → Validate & create user in Firebase
    - **[Login here]** → `/login` (replaces)

    ---

    ## HOME SCREEN

    **File:** `lib/screens/home_screen.dart`  
    **Route:** `/home`  
    **Purpose:** Main dashboard after authentication

    ### Theme:
    - **Background:** White to light grey gradient
    - **Header:** Gradient grey bar with light underline
    - **Accent:** Dark grey tiles (#6E6E6E)
    - **Text:** Dark colors (#2C3E50, #7F8C8D)

    ### Layout:
    ```
    ┌────────────────────────────────────────┐
    │ [👤]  Quiz Application      [⚙️]     │ (Gradient header)
    ├────────────────────────────────────────┤
    │                                        │
    │  Hello, [Username]                     │ (32px bold)
    │  What would you like to do today?      │ (16px grey)
    │                                        │
    │  ┌──────────────────┐ ┌──────────────┐│
    │  │ ⊕ Create Quiz    │ │ 🎯 Take Quiz ││ (2x2 grid, neumorphic cards)
    │  │ Design your own  │ │ Enter quiz   ││
    │  │ Quiz             │ │ code         ││
    │  └──────────────────┘ └──────────────┘│
    │                                        │
    │  ┌──────────────────┐ ┌──────────────┐│
    │  │ 📕 Quiz board    │ │ ⏱️ Quiz      ││
    │  │ 25 Created       │ │ Taken        ││
    │  │ 5 Published      │ │ 45 Submitted ││
    │  │ 2 drafts         │ │ 89% avg      ││
    │  │                  │ │ score        ││
    │  └──────────────────┘ └──────────────┘│
    │                                        │
    │  recent activity                       │ (14px grey, 600 weight)
    │  ┌────────────────────────────────────┐│
    │  │ Quiz Title                         ││ (Dark grey box)
    │  │ 3 days ago              View Details││
    │  └────────────────────────────────────┘│
    │  ┌────────────────────────────────────┐│
    │  │ Quiz Title 2                       ││
    │  │ 1 week ago              View Details││
    │  └────────────────────────────────────┘│
    │  ┌────────────────────────────────────┐│
    │  │ No recent activity                 ││ (If empty)
    │  └────────────────────────────────────┘│
    │                                        │
    └────────────────────────────────────────┘
    ```

    ### Action Tiles (2x2 Grid):
    1. **Create Quiz** - Icon: add_circle (48px)
    2. **Take Quiz** - Icon: gps_fixed (48px), opens dialog
    3. **Quiz board** - Icon: menu_book (48px)
    4. **Quiz Taken** - Icon: history (48px)

    Each tile:
    - Neumorphic styling (gradient border, inset shadow)
    - Title (18px bold)
    - Subtitle (12px grey)
    - Tap-to-navigate

    ### Recent Activity:
    - Shows last 5 quizzes (by creation date descending)
    - Each item: Title, relative time, "View Details" button
    - Dark grey background (#6E6E6E)
    - Relative time: "3 days ago", "1 week ago", etc.

    ### Navigation:
    - **[👤]** → `/profile`
    - **[⚙️]** → `/profile`
    - **[Create Quiz]** → `/create_quiz`
    - **[Take Quiz]** → `showTakeQuizDialog()`
    - **[Quiz board]** → `/my_quizzes`
    - **[Quiz Taken]** → `/quiz_history`
    - **[View Details]** → `/edit_quiz` (with quiz ID)

    ---

    ## TAKE QUIZ DIALOG

    **File:** `lib/screens/take_quiz_dialog.dart`  
    **Purpose:** Search for and preview quiz before taking

    ### Step 1 - Enter Code:
    ```
    ┌──────────────────────────────────┐
    │  Enter Quiz Code        [X]      │
    ├──────────────────────────────────┤
    │                                  │
    │  ┌────────────────────────────┐ │
    │  │ Quiz code    [📋 Paste]   │ │ (TextField with paste button)
    │  └────────────────────────────┘ │
    │                                  │
    │  ◐ Loading...                    │ (If searching)
    │                                  │
    │  [Close]          [Take Quiz]    │ (Action buttons)
    │                                  │
    └──────────────────────────────────┘
    ```

    ### Step 2 - Confirm Quiz:
    ```
    ┌──────────────────────────────────┐
    │  [Quiz Title]           [X]      │
    ├──────────────────────────────────┤
    │                                  │
    │  [Optional description text]     │
    │                                  │
    │  Questions: 10                   │
    │  Author: John Doe                │
    │                                  │
    │  [Close]        [Attempt Quiz]   │
    │                                  │
    └──────────────────────────────────┘
    ```

    ### Features:
    - Paste from clipboard button
    - Search quiz by code
    - Display quiz details (title, description, questions count, author)
    - Error handling: "No quiz found for that code"
    - Two-step flow: search → confirm

    ### Navigation:
    - **[Paste]** → Clipboard → paste into field
    - **[Take Quiz]** (on confirmation) → `/take_quiz` with quiz ID
    - **[Close]** → Dismiss dialog

    ---

    ## CREATE QUIZ SCREEN

    **File:** `lib/screens/create_quiz_screen.dart`  
    **Route:** `/create_quiz`  
    **Purpose:** Initialize a new quiz

    ### Theme:
    - **Background:** White to light grey gradient
    - **Header:** Gradient (grey) with light underline
    - **Title Color:** #2C3E50

    ### Layout:
    ```
    ┌────────────────────────────────────┐
    │ [<]      Create Quiz           []  │ (Gradient header)
    ├────────────────────────────────────┤
    │                                    │
    │         New Quiz Details           │ (24px bold, centered)
    │   Set the basic information for    │ (14px grey, centered)
    │      your new quiz.                │
    │                                    │
    │                                    │ (32px gap)
    │                                    │
    │  ┌────────────────────────────────┐│
    │  │ Title                          ││
    │  │ [________________________]      ││
    │  │                                ││
    │  │ Description                    ││
    │  │ [________________________]      ││
    │  │                                ││
    │  │ Time limit (minutes)           ││
    │  │ [10]                           ││
    │  │                                ││
    │  │      [Continue]                ││
    │  └────────────────────────────────┘│
    │                                    │
    └────────────────────────────────────┘
    ```

    ### Input Fields:
    - **Title** (required, text input)
    - **Description** (optional, text input)
    - **Time limit** (default: 10 minutes, numeric input)

    ### Features:
    - Form in neumorphic container (gradient border + inset)
    - Light background (#F5F5F5)
    - Validation: Title required
    - Auto-generates 6-digit quiz code
    - Sets `published: false`

    ### Actions:
    - **[<]** → Pop to previous
    - **[Continue]** → Create quiz & navigate to `/edit_quiz`

    ---

    ## EDIT QUIZ SCREEN

    **File:** `lib/screens/edit_quiz_screen.dart`  
    **Route:** `/edit_quiz` (args: quizId)  
    **Purpose:** Manage questions and quiz settings

    ### Theme:
    - **Background:** White to grey gradient
    - **Header:** Gradient with action button
    - **Button Color:** Dark grey (#2C3E50) or red (#C0392B) if published

    ### Layout:
    ```
    ┌──────────────────────────────────────┐
    │ [<]  [Quiz Title]    [Publish/Unpub] │ (Header with action button)
    ├──────────────────────────────────────┤
    │                                      │
    │  Quiz description text               │ (16px, centered)
    │                                      │
    │  ┌──────────────────────────────────┐│
    │  │ "Add at least one question to    ││ (If no questions)
    │  │  start building your quiz"       ││
    │  └──────────────────────────────────┘│
    │                                      │
    │  Questions (3):                      │
    │  ┌────────────────────────────────┐ │
    │  │ Q1: What is...?                │ │
    │  │ Multiple Choice | 5 pts         │ │
    │  │                   [Edit] [Delete] │
    │  └────────────────────────────────┘ │
    │                                      │
    │  ┌────────────────────────────────┐ │
    │  │ Q2: True or False...?          │ │
    │  │ True/False | 3 pts              │ │
    │  │                   [Edit] [Delete] │
    │  └────────────────────────────────┘ │
    │                                      │
    │  ┌────────────────────────────────┐ │
    │  │ Q3: Short Answer...?           │ │
    │  │ Short Answer | 2 pts            │ │
    │  │                   [Edit] [Delete] │
    │  └────────────────────────────────┘ │
    │                                      │
    │  ⚙️ SETTINGS PANEL (Collapsible)     │
    │  ┌────────────────────────────────┐ │
    │  │ ☐ Shuffle Questions            │ │
    │  │ ☐ Shuffle Answer Options       │ │
    │  │ ☐ Single Response Mode         │ │
    │  │ Time: [10] minutes             │ │
    │  │ ☐ Enable Password              │ │
    │  │    Password: [_______]         │ │
    │  │ [Save Settings]                │ │
    │  └────────────────────────────────┘ │
    │                                      │
    │                   [+ Add Question]   │ (FAB bottom-right)
    │                                      │
    └──────────────────────────────────────┘
    ```

    ### Question List Item:
    - Question text (first line)
    - Type + Points (grey text)
    - [Edit] and [Delete] buttons

    ### Settings Panel:
    - Shuffle Questions (toggle)
    - Shuffle Answer Options (toggle)
    - Single Response Mode (toggle)
    - Time limit input
    - Optional password protection
    - [Save Settings] button

    ### Features:
    - Load quiz and all questions on first load
    - Add/edit/delete questions
    - Edit question opens QuestionEditor dialog
    - Publish validation:
    - At least 1 question required
    - Multiple choice/checkbox/dropdown must have correct answers
    - Publish dialog shows question count & total points
    - Copy quiz code to clipboard on publish

    ### Navigation:
    - **[<]** → Pop
    - **[Publish/Unpublish]** → Show confirmation, then publish/unpublish
    - **[Edit]** (on question) → QuestionEditor dialog
    - **[Delete]** (on question) → Delete with reload
    - **[+ Add Question]** → QuestionEditor dialog (new)

    ---

    ## QUESTION EDITOR DIALOG

    **File:** `lib/screens/question_editor.dart`  
    **Purpose:** Create/edit individual questions

    ### Layout:
    ```
    ┌──────────────────────────────────────┐
    │  Add/Edit Question            [X]   │
    ├──────────────────────────────────────┤
    │                                      │
    │ Question Type:                       │
    │ [Multiple Choice        ▼]           │ (Dropdown)
    │  • Multiple Choice                   │
    │  • True/False                        │
    │  • Short Answer                      │
    │  • Paragraph                         │
    │                                      │
    │ Question Text: *                     │
    │ ┌────────────────────────────────┐  │
    │ │ [Question prompt input]        │  │
    │ └────────────────────────────────┘  │
    │                                      │
    │ Points: [1  ▼]                      │
    │                                      │
    │ Answer Options:                      │
    │ ☐ [Option A: ________]              │
    │ ☐ [Option B: ________]              │
    │ ☐ [Option C: ________]              │
    │ ☐ [Option D: ________]              │
    │                                      │
    │ [+ Add Option]  [Remove Last]       │
    │                                      │
    │ [Cancel]          [Save Question]    │
    │                                      │
    └──────────────────────────────────────┘
    ```

    ### Question Types:
    1. **Multiple Choice** - Select one correct answer
    2. **True/False** - Two options (T/F)
    3. **Short Answer** - Text input (case-insensitive match)
    4. **Paragraph** - Longer text response

    ### Features:
    - Checkbox selection for marking correct answers
    - Add/remove answer options dynamically
    - Points per question (1+)
    - Question text required
    - Validate before saving

    ### Navigation:
    - **[Cancel]** → Close dialog (no save)
    - **[Save Question]** → Validate & save to Firestore, return to Edit Quiz

    ---

    ## MY QUIZZES SCREEN

    **File:** `lib/screens/my_quizzes_screen.dart`  
    **Route:** `/my_quizzes`  
    **Purpose:** View and manage all quizzes created by user

    ### Theme:
    - **Background:** White to grey gradient
    - **Header:** Gradient with action buttons (appear during multi-select)

    ### Layout:
    ```
    ┌────────────────────────────────────────┐
    │ [<]    My Quizzes      [☓ ◯ 🗑 ☰]     │ (Multi-select icons on top-right)
    ├────────────────────────────────────────┤
    │                                        │
    │  Sort: [Updated ▼]                    │
    │  Filter: [All ▼]                      │
    │  Search: [_____________________]      │
    │                                        │
    │  PUBLISHED                          (3)│ (Section header with count)
    │  ┌────────────────────────────────────┐│
    │  │ ☐ Quiz Title 1                     ││
    │  │   Code: 123456  [📋 Copy]          ││
    │  │   Created: 3 days ago              ││
    │  │   10 Questions | Published         ││
    │  │   [Edit] [Analyze] [...]           ││
    │  └────────────────────────────────────┘│
    │  ┌────────────────────────────────────┐│
    │  │ ☐ Quiz Title 2                     ││
    │  │   Code: 654321  [📋 Copy]          ││
    │  │   Created: 1 week ago              ││
    │  │   8 Questions | Published          ││
    │  │   [Edit] [Analyze] [...]           ││
    │  └────────────────────────────────────┘│
    │                                        │
    │  DRAFTS                             (1)│ (Section header)
    │  ┌────────────────────────────────────┐│
    │  │ ☐ Quiz Title 3                     ││
    │  │   Code: 456789  [📋 Copy]          ││
    │  │   Created: 2 weeks ago             ││
    │  │   3 Questions | Draft              ││
    │  │   [Edit] [Analyze] [...]           ││
    │  └────────────────────────────────────┘│
    │                                        │
    │ (FAB with counter if selections active)
    │                 [✓ 2 selected]        │
    │                                        │
    └────────────────────────────────────────┘
    ```

    ### Filter & Sort Options:
    - **Sort:** Updated, Name, Created
    - **Filter:** All, Recent, Incomplete, Popular
    - **Search:** Real-time filtering by title

    ### Quiz Item:
    - Checkbox (multi-select)
    - Quiz title
    - Quiz code with copy button
    - Created date (relative: "3 days ago")
    - Question count + status (Published/Draft)
    - Action buttons: [Edit], [Analyze], [More]

    ### Multi-Select:
    - Checkboxes visible when selecting
    - Top buttons appear:
    - [☓] Clear selection
    - [◯] Publish selected
    - [🗑] Delete selected
    - FAB shows count: "[✓ 2 selected]"

    ### Copy Feedback:
    - SnackBar message: "Quiz code copied"
    - 1-second duration
    - Cooldown: 800ms between copies

    ### Navigation:
    - **[<]** → Pop
    - **[Edit]** → `/edit_quiz` with quiz ID
    - **[Analyze]** → `/quiz_analysis` with quiz ID
    - **[...]** (more menu) → Additional options

    ---

    ## PROFILE SCREEN

    **File:** `lib/screens/profile_screen.dart`  
    **Route:** `/profile`  
    **Purpose:** User account management and statistics

    ### Theme:
    - **Background:** White to grey gradient
    - **Header:** Gradient with edit/save buttons

    ### Layout:
    ```
    ┌────────────────────────────────────┐
    │ [<]      Profile       [Edit/Save] │ (Header with toggle button)
    ├────────────────────────────────────┤
    │                                    │
    │  Email: user@example.com           │
    │  (display only, no edit)           │
    │                                    │
    │  ┌────────────────────────────────┐│
    │  │ First Name                     ││
    │  │ [John         ] (or form input)││
    │  │                                ││
    │  │ Last Name                      ││
    │  │ [Doe          ] (or form input)││
    │  │                                ││
    │  │ Class/Section                  ││
    │  │ [Grade 10-A   ] (or form input)││
    │  └────────────────────────────────┘│
    │                                    │
    │  STATISTICS                        │
    │  Quizzes Created: 5                │
    │  Quizzes Taken: 12                 │
    │  Average Score: 82%                │
    │                                    │
    │  [Change Password]                 │
    │  [Privacy Settings]                │
    │  [Report Issue]                    │
    │  [Logout]                          │
    │                                    │
    └────────────────────────────────────┘
    ```

    ### Edit Mode:
    - First Name, Last Name, Class/Section become editable text fields
    - Form validation (trim whitespace)
    - [Save] button replaces [Edit]
    - SnackBar feedback: "Profile created" or "Profile updated"

    ### Features:
    - Load profile from Firestore or Firebase Auth
    - Create profile if doesn't exist
    - Edit and save profile
    - Display user statistics
    - Account settings links
    - Logout functionality

    ### Navigation:
    - **[<]** → Pop
    - **[Change Password]** → (Link/action)
    - **[Privacy Settings]** → (Link/action)
    - **[Report Issue]** → (Link/action)
    - **[Logout]** → Clear auth & navigate to `/starter`

    ---

    ## QUIZ HISTORY SCREEN

    **File:** `lib/screens/quiz_history_screen.dart`  
    **Route:** `/quiz_history`  
    **Purpose:** View all quiz attempts taken by user

    ### Theme:
    - **Background:** White to grey gradient
    - **Header:** Gradient header

    ### Layout:
    ```
    ┌────────────────────────────────────┐
    │ [<]   Quiz History                 │
    ├────────────────────────────────────┤
    │                                    │
    │  Filter: [All ▼]                  │
    │  Search: [_______________]        │
    │                                    │
    │  Attempts:                         │
    │  ┌────────────────────────────────┐│
    │  │ Quiz Title 1                   ││
    │  │ Attempt #1 | Score: 85/100     ││
    │  │ Completed: Jan 30, 10:30 AM    ││
    │  │ [View Details] [Review]        ││
    │  └────────────────────────────────┘│
    │                                    │
    │  ┌────────────────────────────────┐│
    │  │ Quiz Title 2                   ││
    │  │ Attempt #2 | Score: 92/100     ││
    │  │ Completed: Jan 28, 3:15 PM     ││
    │  │ [View Details] [Review]        ││
    │  └────────────────────────────────┘│
    │                                    │
    │  ┌────────────────────────────────┐│
    │  │ Quiz Title 1                   ││
    │  │ Attempt #1 | Score: 78/100     ││
    │  │ Completed: Jan 25, 2:00 PM     ││
    │  │ [View Details] [Review]        ││
    │  └────────────────────────────────┘│
    │                                    │
    │  [Load More]                       │
    │                                    │
    └────────────────────────────────────┘
    ```

    ### Attempt Item:
    - Quiz title (linked to quiz details)
    - Attempt number and score (e.g., "Attempt #1 | Score: 85/100")
    - Completion timestamp
    - [View Details] and [Review] buttons

    ### Features:
    - Load attempts from Firestore
    - Prefetch quiz titles for display
    - Relative timestamps
    - Filter/search options (if implemented)

    ### Navigation:
    - **[<]** → Pop
    - **[Review]** → `/quiz_analysis` with quiz ID

    ---

    ## TAKE QUIZ PAGE

    **File:** `lib/screens/take_quiz_page.dart`  
    **Route:** `/take_quiz` (args: quizId)  
    **Purpose:** Full interactive quiz interface with anti-cheat monitoring

    ### Theme:
    - Light theme (varies by content)
    - Header with timer

    ### Layout:
    ```
    ┌────────────────────────────────────────┐
    │ Quiz: "Title"  ⏱ 9:45  [☰ Menu]      │ (Header with timer & menu)
    ├────────────────────────────────────────┤
    │                                        │
    │  Question 1 of 10                      │
    │  ┌────────────────────────────────────┐│
    │  │ Which of the following is...?     ││ (Question text)
    │  └────────────────────────────────────┘│
    │                                        │
    │  ☐ Option A                            │
    │  ☐ Option B                            │
    │  ☐ Option C                            │
    │  ☐ Option D                            │
    │                                        │
    │  [❤ Flag] [< Previous] [Next >]        │ (Navigation buttons)
    │                                        │
    │  QUESTION NAVIGATOR                    │
    │  ┌────────────────────────────────────┐│
    │  │ 1  2  3  4  5  6  7  8  9  10     ││
    │  │ ■  □  ■  □  □  □  ■  □  □  ☐     ││
    │  │ ■ = Answered                       ││
    │  │ □ = Not Answered                   ││
    │  │ ☐ = Flagged                        ││
    │  └────────────────────────────────────┘│
    │                                        │
    │  [Submit Quiz]                         │
    │                                        │
    └────────────────────────────────────────┘
    ```

    ### Features:
    - **Timer:** Countdown in MM:SS format
    - **Question Display:** Text + media (if applicable)
    - **Answer Types:**
    - Multiple choice (radio buttons)
    - Checkbox (multiple select)
    - True/False
    - Short/paragraph answer (text input)
    - **Flag System:** Mark questions to review later
    - **Navigation:** Previous/Next buttons + question grid
    - **Submit:** Final submission dialog

    ### Anti-Cheat Monitoring:
    - App state detection (background/foreground)
    - Screen size validation
    - Accessibility service monitoring
    - Usage stats tracking
    - Real-time violation logging (local + Firestore)
    - Violation alerts during quiz

    ### Question Navigator:
    - Grid showing all questions (status indicators)
    - Click to jump to question
    - Color coding: answered, unanswered, flagged

    ### Navigation:
    - **[< Previous]** → Go to previous question
    - **[Next >]** → Go to next question
    - **[Question number]** → Jump to question
    - **[❤ Flag]** → Toggle flag status
    - **[Submit Quiz]** → Show confirmation & submit

    ---

    ## QUIZ ANALYSIS SCREEN

    **File:** `lib/screens/quiz_analysis_screen.dart`  
    **Route:** `/quiz_analysis` (args: quizId, initialTab)  
    **Purpose:** Detailed instructor analytics and result review

    ### Theme:
    - Light theme
    - Tab navigation

    ### Layout:
    ```
    ┌─────────────────────────────────────────┐
    │ [Summary] [Insights] [Individual]  [<] │ (Tab navigation)
    ├─────────────────────────────────────────┤
    │                                         │
    │ TAB 1: SUMMARY                          │
    │                                         │
    │ Quiz: "Quiz Title"                      │
    │ Code: 123456                            │
    │                                         │
    │ Statistics:                             │
    │ ┌─────────────────────────────────────┐│
    │ │ Total Attempts: 25                  ││
    │ │ Average Score: 82.4%                ││
    │ │ Highest Score: 100%                 ││
    │ │ Lowest Score: 45%                   ││
    │ │ Median Score: 84%                   ││
    │ └─────────────────────────────────────┘│
    │                                         │
    │ Score Distribution:                     │
    │ ┌─────────────────────────────────────┐│
    │ │ [Bar Chart]                         ││
    │ │ 0-20%:   1 ■                        ││
    │ │ 20-40%:  2 ■■                      ││
    │ │ 40-60%:  5 ■■■■■                  ││
    │ │ 60-80%: 12 ■■■■■■■■■■■■          ││
    │ │ 80-100%: 5 ■■■■■                  ││
    │ └─────────────────────────────────────┘│
    │                                         │
    │ Question Performance:                   │
    │ [Q1: 92% correct] [Q2: 68% correct]   │
    │ [Q3: 100% correct] [Q4: 44% correct]  │
    │                                         │
    │ ─────────────────────────────────────── │
    │                                         │
    │ TAB 2: INSIGHTS                         │
    │                                         │
    │ Difficult Questions:                    │
    │ • Q7: Only 32% correct (below avg)      │
    │ • Q4: Only 44% correct (below avg)      │
    │ • Q2: Only 68% correct (below avg)      │
    │                                         │
    │ Easy Questions:                         │
    │ • Q1: 92% correct (above avg)           │
    │ • Q3: 100% correct (above avg)          │
    │ • Q5: 88% correct (above avg)           │
    │                                         │
    │ Time Analysis:                          │
    │ • Avg Time per Question: 2m 15s         │
    │ • Questions with violations: 5          │
    │ • Most flagged: Q3, Q7                  │
    │                                         │
    │ [View Violation Reports]                │
    │                                         │
    │ ─────────────────────────────────────── │
    │                                         │
    │ TAB 3: INDIVIDUAL ATTEMPTS              │
    │                                         │
    │ Student: [John Doe                 ▼] │ (Dropdown selector)
    │                                         │
    │ Attempt #1                              │
    │ Score: 85/100 (85%)                    │
    │ Completed: Jan 30, 10:30 AM            │
    │ Time Taken: 12m 45s                    │
    │ Status: Completed                      │
    │                                         │
    │ Answer Review:                          │
    │ ┌─────────────────────────────────────┐│
    │ │ Q1: ✓ Multiple Choice               ││
    │ │     Selected: A (Correct)           ││
    │ │ Q2: ✗ True/False                   ││
    │ │     Selected: F (Wrong)             ││
    │ │     Answer Key: T                   ││
    │ │ Q3: ✓ Short Answer                 ││
    │ │     Entered: "Paris"                ││
    │ │     Correct: "Paris"                ││
    │ └─────────────────────────────────────┘│
    │                                         │
    │ Violations Detected: 2                  │
    │ • App switched at Q4 (10:40)            │
    │ • Screen off at Q7 (10:52)              │
    │                                         │
    │ [Edit Time] [Recalculate] [Save]       │
    │                                         │
    └─────────────────────────────────────────┘
    ```

    ### Tab 1: Summary
    - Quiz metadata (title, code)
    - Overall statistics (avg, min, max, median, std dev)
    - Score distribution chart
    - Question performance overview

    ### Tab 2: Insights
    - Difficult questions (below average)
    - Easy questions (above average)
    - Time analysis
    - Violation summary
    - Actionable insights

    ### Tab 3: Individual
    - Student dropdown selector
    - Attempt details
    - Answer-by-answer review (correct/incorrect)
    - Violation timeline
    - Edit/recalculate actions

    ### Features:
    - Load quiz, questions, attempts, users, violations
    - Calculate statistics
    - Generate charts
    - Compare student answers vs answer key
    - Review violations
    - Edit attempt details
    - Recalculate scores

    ### Navigation:
    - **[< Back]** → Pop
    - **[Student dropdown]** → Filter attempts
    - **[Edit Time]** → Modify attempt timestamp
    - **[Recalculate]** → Recompute score

    ---

    ## NAVIGATION FLOW

    ```
    SPLASH SCREEN
        ↓
        ├──→ [Authenticated] ───→ HOME SCREEN
        │          │
        │          ├→ [👤] ──────────→ PROFILE SCREEN
        │          │                        ↓
        │          │                    [Logout] ──→ STARTER SCREEN
        │          │
        │          ├→ [Create Quiz] ──→ CREATE QUIZ ──→ EDIT QUIZ
        │          │                          ↓
        │          │                    QUESTION EDITOR
        │          │                    (Modal dialog)
        │          │
        │          ├→ [Take Quiz] ────→ TAKE QUIZ DIALOG
        │          │                        ↓
        │          │                    TAKE QUIZ PAGE
        │          │                        ↓
        │          │                    SUBMISSION
        │          │
        │          ├→ [Quiz board] ───→ MY QUIZZES SCREEN
        │          │                        ├→ [Edit] ──→ EDIT QUIZ
        │          │                        ├→ [Analyze] ──→ QUIZ ANALYSIS
        │          │                        └→ [Delete] (with undo)
        │          │
        │          └→ [Quiz Taken] ────→ QUIZ HISTORY SCREEN
        │                                   └→ [Review] ──→ QUIZ ANALYSIS
        │
        └──→ [Not Authenticated] ───→ STARTER SCREEN
                ├→ [Login] ────→ LOGIN SCREEN
                │                   ├→ [Sign up] ──→ SIGNUP SCREEN
                │                   │                   ↓
                │                   │              [Login here] ──→ LOGIN
                │                   │
                │                   └→ [Forgot?] ──→ Reset Password Dialog
                │                                     ↓
                │                                 Email verification
                │
                └→ [Sign Up] ────→ SIGNUP SCREEN
                                    ├→ [Create Account] ──→ Create Auth User
                                    │                        ↓
                                    │                   [Login here] ──→ LOGIN
                                    │
                                    └→ [Login here] ──→ LOGIN SCREEN


    GLOBAL FEATURES:
    • Report Bug Dialog available on STARTER, LOGIN, SIGNUP (modal)
    • Keyboard handling with auto-scroll on focus
    • Toast notifications for errors/confirmations
    • Loading states with spinners
    • Responsive design for tablet/wide screens
    ```

    ---

    ## AUTHENTICATION FLOW

    ```
    STARTER SCREEN
    ├─ Login Button → LOGIN SCREEN
    │    ├─ Email + Password input
    │    ├─ Forgot Password → Reset Password Dialog
    │    └─ Sign Up link → SIGNUP SCREEN
    │
    └─ Sign Up Button → SIGNUP SCREEN
        ├─ First Name + Last Name
        ├─ Email + Password (2x)
        └─ Login link → LOGIN SCREEN

    LOGIN/SIGNUP → Firebase Auth
    ├─ Email/Password validation
    ├─ Create Firestore user profile
    └─ Navigate to HOME SCREEN
    ```

    ---

    ## COLOR PALETTE

    ### Light Mode Screens (Starter, Login, Signup, Create, Edit, etc.):
    - **Background:** White (#FFFFFF) to light grey (#9B9B9B)
    - **Text:** Dark grey (#4A4A4A, #2C3E50)
    - **Accent:** Red (#FF3B30, #E94057)
    - **Input:** Gradient borders (black → white)
    - **Cards:** Light grey backgrounds (#F5F5F5, #E8E8E8)

    ### Dark Mode Elements (Quiz History, Home Recent Activity):
    - **Background:** Dark grey (#6E6E6E)
    - **Text:** Light grey (#C0C0C0, #E0E0E0)
    - **Accent:** Same red

    ### Button Colors:
    - **Primary:** Dark grey (#2C3E50)
    - **Publish:** Dark grey (#2C3E50)
    - **Unpublish:** Dark red (#C0392B)
    - **Create Account:** Red (#E94057)
    - **Cancel/Reset:** Red gradient

    ---

    ## KEY COMPONENT STYLES

    ### Neumorphic Cards (Home Screen):
    ```
    Outer Container:
    - Gradient border (white top-left to black bottom-right)
    - Border radius: 20px
    - 3px padding

    Inner Container:
    - Gradient fill (grey #A6A6A6 to white)
    - Border radius: 17px
    - 12px padding
    ```

    ### Gradient Input Fields:
    ```
    CustomPaint with _GradientPainter:
    - Stroke width: 2px
    - Radius: 12px
    - Gradient: Black → Grey → White → White
    - Height: 60px
    - Icon + TextField inside
    ```

    ### Button Styles:
    ```
    Image Buttons:
    - assets/images/[button_name].png
    - Ripple effect (splash color)
    - Highlight color on tap

    Gradient Buttons:
    - Height: 44-60px
    - Border radius: 22px
    - Gradient fill
    - Shadow effect
    ```

    ---

    ## RESPONSIVE DESIGN

    - **Mobile:** Full width, portrait orientation (login/signup)
    - **Tablet:** Wider screens use ConstrainedBox (max 600-900px)
    - **Landscape:** Some screens restrict to portrait only

    ---

    ## ACCESSIBILITY FEATURES

    - High contrast colors
    - Clear button labels
    - Icon + text combinations
    - Keyboard support
    - Focus visible states
    - Auto-scroll on input focus

