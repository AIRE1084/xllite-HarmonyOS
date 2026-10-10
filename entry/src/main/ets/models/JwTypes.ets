export interface Course {
  day: string
  slot: string
  title: string
  teacher: string
  weeks: string
  sections: string
  location: string
}

export interface ScheduleData {
  term: string
  courses: Course[]
}

export interface GradeSummary {
  courseCount: number
  totalCredits: number
  gpaCredits: number
  weightedGradePoint: number
  failedCourseCount: number
  failedCredits: number
}

export interface TermSummary {
  term: string
  courseCount: number
  totalCredits: number
  gpaCredits: number
  weightedGradePoint: number
  failedCourseCount: number
  failedCredits: number
}

export interface GradeItem {
  term: string
  courseCode: string
  courseName: string
  score: string
  credit: string
  gradePoint: string
  examNature: string
  scoreFlag: string
  makeupTerm: string
}

export interface GradesData {
  mode: string
  summary: GradeSummary
  rawSummary: GradeSummary
  terms: TermSummary[]
  normalGrades: GradeItem[]
  makeupGrades: GradeItem[]
  failedCourses: GradeItem[]
}

export interface Exam {
  courseName: string
  teacher: string
  examTime: string
  examPlace: string
  seatNo: string
  courseCode: string
  examSession: string
  campus: string
}

export interface ExamsData {
  exams: Exam[]
}

export interface ProfileData {
  studentId: string
  name: string
  college: string
  major: string
  className: string
  grade: string
  gender: string
}

export interface TrainingItem {
  graduationYear: string
  graduationType: string
  graduationConclusion: string
  graduationTime: string
  certificateNo: string
}

export interface TrainingData {
  training: TrainingItem[]
}
