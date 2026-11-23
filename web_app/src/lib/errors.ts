// Server refusals → words a parent (or, in the child zone, a grown-up reading over a shoulder) understands.
const WORDS: Record<string, string> = {
  VALIDATION: "Something in the form isn't right.",
  UNAUTHORIZED: "Please sign in again.",
  REAUTH_REQUIRED: "For your security, please sign in again first.",
  CHILD_LIMIT: "Your plan doesn't allow more children.",
  FORBIDDEN: "That isn't allowed.",
  NOT_FOUND: "We couldn't find that.",
  CONFLICT: "That changed in the meantime. Please try again.",
  NEEDS_PLUS: "This one is part of Plus. Ask a grown-up.",
  AGE_NOT_SUITABLE: "This one is for a different age.",
  SECTION_DISABLED: "A grown-up switched this off.",
  CATEGORY_BLOCKED: "A grown-up switched this off.",
  SCREEN_TIME_OVER: "That's all for today!",
  RATE_LIMITED: "Too many tries. Please wait a little and try again.",
  ACCOUNT_SUSPENDED: "This account is on hold. A grown-up can contact support.",
};
export const sayError = (type: string, detail?: string) =>
  type === "VALIDATION" && detail ? `Please check: ${detail}.` : WORDS[type] ?? "Something went wrong. Please try again.";
