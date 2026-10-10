export interface CurrentWeek {
  term: string
  week: number
  totalWeeks: number
  termStartDate: string
  today: string
}

// The schedule response owns the semester data; do not cache a stale default or wait on a timer.
export async function fetchCurrentWeek(term: string = ''): Promise<CurrentWeek> {
  return {
    term: AppStorage.get<string>('term') ?? term,
    week: getCurrentWeek(), totalWeeks: getTotalWeeks(),
    termStartDate: '', today: new Date().toISOString(),
  }
}
export function getCurrentWeek(): number { return AppStorage.get<number>('currentWeek') ?? 1 }
export function getTotalWeeks(): number { return AppStorage.get<number>('totalWeeks') ?? 20 }
export function getTerm(): string { return AppStorage.get<string>('term') ?? '' }
