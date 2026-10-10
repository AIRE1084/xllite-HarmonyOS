/** Replaces list snapshots without constructing every row. */
export class ListDataSource<T> implements IDataSource {
  private items: T[] = []
  private listeners: DataChangeListener[] = []
  totalCount(): number { return this.items.length }
  getData(index: number): T { return this.items[index] }
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) this.listeners.push(listener)
  }
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener)
    if (index >= 0) this.listeners.splice(index, 1)
  }
  replace(items: T[]): void {
    this.items = items.slice()
    this.listeners.forEach((listener: DataChangeListener) => listener.onDataReloaded())
  }
}
