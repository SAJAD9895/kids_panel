import { z } from "zod";
/** Supabase Auth's password policy for this project (docs/backend/authentication.md §2). */
export const strongPassword = z.string().min(10, "At least 10 characters").regex(/[a-z]/, "Add a lower-case letter")
  .regex(/[A-Z]/, "Add a capital letter").regex(/\d/, "Add a number");
/** The policy version parents accept at sign-up (the same as the app's AppConfig.policyVersion). */
export const POLICY_VERSION = "2026-11";
