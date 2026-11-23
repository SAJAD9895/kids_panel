/** An error whose message is shown on the form as is. */
export class FormError extends Error {
  constructor(message: string, public code?: string) { super(message); }
}
