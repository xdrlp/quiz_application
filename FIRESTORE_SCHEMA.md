/**
 * FIRESTORE SCHEMA DOCUMENTATION
 * Quiz Application - Complete Data Model
 * 
 * This document defines all Firestore collections, document structure,
 * field types, and recommended indexes for optimal query performance.
 */

// ============================================================================
// COLLECTION: users
// ============================================================================
// Purpose: Store user profiles and metadata
// Document ID: Firebase Auth UID
// Access: User can read/write own document; teachers can read their students

users/{uid} {
  // Core Identity
  email: string                    // User's email (from Firebase Auth)
  displayName: string              // User's display name
  role: number                     // 0 = teacher, 1 = student (enum index)
  
  // Membership
  classes: array<string>           // Array of class IDs user is member of
  
  // Timestamps
  createdAt: timestamp             // Account creation time
  updatedAt: timestamp             // Last profile update
  
  // Optional: Analytics
  totalQuizzesTaken: number        // (for student) count of attempts
  totalQuizzesCreated: number      // (for teacher) count of quizzes created
  
  // Example Document:
  // {
  //   email: "john@school.com",
  //   displayName: "John Doe",
  //   role: 1,  // student
  //   classes: ["class_001", "class_002"],
  //   createdAt: Timestamp(2025-01-15 10:30:00),
  //   updatedAt: Timestamp(2025-01-15 10:30:00),
  //   totalQuizzesTaken: 5
  // }
}

// ============================================================================
// COLLECTION: classes
// ============================================================================
// Purpose: Define classes/sections for quiz organization
// Document ID: Auto-generated
// Access: Teacher (owner) can read/write; members can read

classes/{classId} {
  // Core Info
  name: string                     // Class name (e.g., "10th Grade Math")
  teacherUid: string              // Owner/teacher UID
  description: string              // (optional) class description
  code: string                     // (optional) code for students to join
  
  // Membership
  memberUids: array<string>        // Array of student UIDs in class
  
  // Timestamps
  createdAt: timestamp
  updatedAt: timestamp
  
  // Example Document:
  // {
  //   name: "Grade 10 Mathematics",
  //   teacherUid: "teacher_uid_123",
  //   description: "Algebra and Geometry",
  //   code: "MATH2025",
  //   memberUids: ["student_1", "student_2", "student_3"],
  //   createdAt: Timestamp(...),
  //   updatedAt: Timestamp(...)
  // }
}

// ============================================================================
// COLLECTION: quizzes
// ============================================================================
// Purpose: Quiz metadata and settings
// Document ID: Auto-generated
// Access: Creator can read/write; published quizzes visible to class/code holders

quizzes/{quizId} {
  // Core Info
  title: string                    // Quiz title
  description: string              // Quiz description
  
  // Timing & Constraints
  timeLimitSeconds: number         // Quiz duration in seconds
  
  // Access Control
  classIds: array<string>          // Empty = public; otherwise restricted to classes
  quizCode: string                 // (optional) unique code for direct access
  published: boolean               // true = visible to students; false = draft
  
  // Settings
  randomizeQuestions: boolean      // Shuffle question order per attempt
  randomizeOptions: boolean        // Shuffle answer choices per attempt
  showScoreImmediately: boolean    // (optional) show results right after submit
  
  // Metadata
  createdBy: string                // Teacher/creator UID
  totalQuestions: number           // Denormalized count (for UI)
  
  // Statistics (denormalized for quick access)
  attemptCount: number             // Total attempts (can be computed from attempts collection)
  averageScore: number             // Average percentage (0-100)
  
  // Timestamps
  createdAt: timestamp
  updatedAt: timestamp
  
  // Example Document:
  // {
  //   title: "Chapter 5 Quiz",
  //   description: "Quadratic equations",
  //   timeLimitSeconds: 1800,  // 30 minutes
  //   classIds: ["class_001"],
  //   quizCode: "QZ5A2025",
  //   published: true,
  //   randomizeQuestions: true,
  //   randomizeOptions: true,
  //   showScoreImmediately: true,
  //   createdBy: "teacher_uid_123",
  //   totalQuestions: 10,
  //   attemptCount: 45,
  //   averageScore: 78.5,
  //   createdAt: Timestamp(...),
  //   updatedAt: Timestamp(...)
  // }
}

// ============================================================================
// COLLECTION: quizzes/{quizId}/questions (Subcollection)
// ============================================================================
// Purpose: Store individual questions for a quiz
// Document ID: Auto-generated
// Access: Same as parent quiz

quizzes/{quizId}/questions/{questionId} {
  // Content
  text: string                     // Question text/prompt
  
  // Choices (array of objects)
  choices: array<{
    id: string,                    // Unique choice ID within question
    text: string                   // Choice text/content
  }>
  
  // Answer
  correctChoiceId: string          // ID of the correct choice
  
  // Scoring
  points: number                   // Points awarded for correct answer
  
  // Organization
  order: number                    // Sort order in quiz (0-based index)
  
  // Timestamps
  createdAt: timestamp
  
  // Example Document:
  // {
  //   text: "What is 2 + 2?",
  //   choices: [
  //     { id: "choice_a", text: "3" },
  //     { id: "choice_b", text: "4" },
  //     { id: "choice_c", text: "5" },
  //     { id: "choice_d", text: "6" }
  //   ],
  //   correctChoiceId: "choice_b",
  //   points: 10,
  //   order: 0,
  //   createdAt: Timestamp(...)
  // }
}

// ============================================================================
// COLLECTION: attempts
// ============================================================================
// Purpose: Track quiz submissions and results
// Document ID: Auto-generated
// Access: Student can read/write own; teacher can read for own quizzes

attempts/{attemptId} {
  // Reference
  quizId: string                   // ID of attempted quiz
  userId: string                   // Student UID who took quiz
  
  // Timing
  startedAt: timestamp             // When quiz started
  submittedAt: timestamp           // When quiz was submitted (null = in-progress)
  
  // Scoring
  score: number                    // Total points earned
  totalPoints: number              // Total possible points
  scorePercentage: number          // Computed: (score/totalPoints)*100
  
  // Answers (array of submission records)
  answers: array<{
    questionId: string,            // Question ID
    selectedChoiceId: string,      // Student's selected choice ID
    timeTakenSeconds: number,      // Time spent on this question
    isCorrect: boolean             // Was the answer correct?
  }>
  
  // Anti-cheat
  totalViolations: number          // Count of detected violations
  flaggedForReview: boolean        // Manual flag for suspicious activity
  
  // Metadata
  deviceInfo: string               // (optional) device type/OS version
  ipAddress: string                // (optional) IP for audit trail
  
  // Timestamps
  createdAt: timestamp             // Same as startedAt
  
  // Example Document:
  // {
  //   quizId: "quiz_001",
  //   userId: "student_uid_456",
  //   startedAt: Timestamp(2025-01-15 14:00:00),
  //   submittedAt: Timestamp(2025-01-15 14:45:30),
  //   score: 85,
  //   totalPoints: 100,
  //   scorePercentage: 85.0,
  //   answers: [
  //     { questionId: "q1", selectedChoiceId: "choice_a", timeTakenSeconds: 12, isCorrect: true },
  //     { questionId: "q2", selectedChoiceId: "choice_c", timeTakenSeconds: 8, isCorrect: false },
  //   ],
  //   totalViolations: 0,
  //   flaggedForReview: false,
  //   deviceInfo: "Android 12",
  //   createdAt: Timestamp(2025-01-15 14:00:00)
  // }
}

// ============================================================================
// COLLECTION: violations
// ============================================================================
// Purpose: Log anti-cheat violations and suspicious activity
// Document ID: Auto-generated
// Access: Teacher can read violations for their quizzes; admin audit trail

violations/{violationId} {
  // Reference
  attemptId: string                // Associated attempt
  userId: string                   // Student UID
  quizId: string                   // (denormalized) quiz ID for quick queries
  
  // Violation Details
  type: number                     // Enum: 0=screenshot, 1=appSwitch, 2=splitScreen, 
                                   //       3=screenResize, 4=rapidResponse, 5=copyPaste, 6=other
  details: string                  // Description (e.g., "App paused for 30s")
  severity: string                 // (optional) "low", "medium", "high"
  
  // Timestamp
  detectedAt: timestamp            // When violation was detected
  
  // Example Document:
  // {
  //   attemptId: "attempt_123",
  //   userId: "student_uid_456",
  //   quizId: "quiz_001",
  //   type: 1,  // appSwitch
  //   details: "App was minimized for 15 seconds",
  //   severity: "medium",
  //   detectedAt: Timestamp(2025-01-15 14:25:45)
  // }
}

// ============================================================================
// FIRESTORE INDEXES
// ============================================================================
// Recommended composite indexes for query performance:

Index 1:
  Collection: quizzes
  Fields: 
    - published (Ascending)
    - classIds (Ascending)
    - createdAt (Descending)
  Purpose: Query available quizzes for a class

Index 2:
  Collection: quizzes
  Fields:
    - createdBy (Ascending)
    - createdAt (Descending)
  Purpose: Query quizzes created by a teacher

Index 3:
  Collection: attempts
  Fields:
    - userId (Ascending)
    - submittedAt (Descending)
  Purpose: Get all attempts by a student (sorted by newest)

Index 4:
  Collection: attempts
  Fields:
    - quizId (Ascending)
    - submittedAt (Descending)
  Purpose: Get all submissions for a quiz

Index 5:
  Collection: violations
  Fields:
    - attemptId (Ascending)
    - detectedAt (Ascending)
  Purpose: Get violations for an attempt in chronological order

Index 6:
  Collection: violations
  Fields:
    - quizId (Ascending)
    - detectedAt (Descending)
  Purpose: Get recent violations for a quiz

// ============================================================================
// FIRESTORE SECURITY RULES
// ============================================================================
// See: firestore.rules file for complete security rule implementation

Key Rules:
- Only authenticated users can access
- Users can only read/write their own user document
- Teachers can read students' attempts for their quizzes
- Students can only see their own attempts
- Violations are write-only for the service, read by teachers/admins
- Quiz updates only by creator
- Classroom data validated by teacher ownership
- Strict schema validation on writes (prevent client tampering)

// ============================================================================
// SAMPLE DATA STRUCTURE (JSON)
// ============================================================================

// User (Student)
{
  "uid": "student_001",
  "email": "alice@school.edu",
  "displayName": "Alice Johnson",
  "role": 1,
  "classes": ["class_101", "class_102"],
  "createdAt": "2024-09-01T08:00:00Z",
  "updatedAt": "2024-09-01T08:00:00Z",
  "totalQuizzesTaken": 12
}

// User (Teacher)
{
  "uid": "teacher_001",
  "email": "mr.smith@school.edu",
  "displayName": "Mr. Smith",
  "role": 0,
  "classes": ["class_101", "class_102"],
  "createdAt": "2023-08-15T09:30:00Z",
  "updatedAt": "2024-09-01T10:15:00Z",
  "totalQuizzesCreated": 28
}

// Class
{
  "id": "class_101",
  "name": "Period 3 - Algebra I",
  "teacherUid": "teacher_001",
  "description": "Foundation of Algebraic Concepts",
  "code": "ALG3P2025",
  "memberUids": ["student_001", "student_002", "student_003"],
  "createdAt": "2024-09-01T08:30:00Z",
  "updatedAt": "2024-09-15T14:20:00Z"
}

// Quiz
{
  "id": "quiz_201",
  "title": "Quadratic Equations - Final",
  "description": "Comprehensive test covering quadratic equations, factoring, and applications",
  "timeLimitSeconds": 3600,
  "classIds": ["class_101"],
  "quizCode": "QUAD_F2025",
  "published": true,
  "randomizeQuestions": true,
  "randomizeOptions": true,
  "showScoreImmediately": false,
  "createdBy": "teacher_001",
  "totalQuestions": 20,
  "attemptCount": 28,
  "averageScore": 76.3,
  "createdAt": "2024-11-15T10:00:00Z",
  "updatedAt": "2024-12-04T08:30:00Z"
}

// Question (within quiz_201/questions)
{
  "id": "q_2501",
  "text": "Solve: x² - 5x + 6 = 0",
  "choices": [
    { "id": "opt_a", "text": "x = 2 or x = 3" },
    { "id": "opt_b", "text": "x = 1 or x = 6" },
    { "id": "opt_c", "text": "x = -2 or x = -3" },
    { "id": "opt_d", "text": "x = 3 or x = 4" }
  ],
  "correctChoiceId": "opt_a",
  "points": 5,
  "order": 0,
  "createdAt": "2024-11-15T10:05:00Z"
}

// Attempt
{
  "id": "attempt_5001",
  "quizId": "quiz_201",
  "userId": "student_001",
  "startedAt": "2024-12-04T09:00:00Z",
  "submittedAt": "2024-12-04T10:35:30Z",
  "score": 75,
  "totalPoints": 100,
  "scorePercentage": 75.0,
  "answers": [
    {
      "questionId": "q_2501",
      "selectedChoiceId": "opt_a",
      "timeTakenSeconds": 45,
      "isCorrect": true
    }
  ],
  "totalViolations": 1,
  "flaggedForReview": false,
  "deviceInfo": "Android 13 - Samsung Galaxy A52",
  "ipAddress": "192.168.1.105",
  "createdAt": "2024-12-04T09:00:00Z"
}

// Violation
{
  "id": "violation_301",
  "attemptId": "attempt_5001",
  "userId": "student_001",
  "quizId": "quiz_201",
  "type": 1,
  "details": "App minimized during question 8",
  "severity": "medium",
  "detectedAt": "2024-12-04T09:45:12Z"
}
