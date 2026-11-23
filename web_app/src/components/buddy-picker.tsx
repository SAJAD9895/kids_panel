import type { Buddy } from "@/lib/data/family";
import { BuddyArt, BUDDY_NAMES, buddyIndex } from "./buddy-art";

/** A radio group of buddies (keyboard: arrow keys move between them, like any radio group). */
export function BuddyPicker({ buddies, name = "avatarId", initial, label = "Choose a buddy" }: { buddies: Buddy[]; name?: string; initial?: string | null; label?: string }) {
  return (
    <fieldset>
      <legend className="text-ui-body-strong">{label}</legend>
      <div className="mt-s3 grid grid-cols-3 gap-s3 sm:grid-cols-4">
        {buddies.map((b, i) => (
          <label key={b.id} className="relative cursor-pointer">
            <input type="radio" name={name} value={b.id} defaultChecked={initial ? initial === b.id : i === 0} className="peer sr-only" />
            <span className="flex aspect-square items-center justify-center rounded-lg border-2 border-ui-border bg-ui-surface p-s2 peer-checked:border-ui-primary peer-checked:bg-ui-primary-soft peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-ui-focus">
              <BuddyArt index={buddyIndex(b.key)} label={BUDDY_NAMES[buddyIndex(b.key)]} />
            </span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}
