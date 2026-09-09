import { reduce, type Action, type Clock, type State } from './model';

export class SerialStore {
  private state: State;
  private tail: Promise<unknown> = Promise.resolve();
  private listeners = new Set<() => void>();
  constructor(initial: State, private persist: (state: State) => Promise<void>, private clock: Clock) { this.state = initial; }
  snapshot = () => this.state;
  subscribe = (listener: () => void) => { this.listeners.add(listener); return () => { this.listeners.delete(listener); }; };
  dispatch = (action: Action): Promise<void> => {
    const result = this.tail.then(async () => {
      const next = reduce(this.state, action, this.clock);
      await this.persist(next);
      this.state = next;
      this.listeners.forEach(listener => listener());
    });
    this.tail = result.catch(() => undefined);
    return result;
  };
}
