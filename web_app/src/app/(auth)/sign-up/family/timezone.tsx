"use client";
import { useEffect, useState } from "react";
/** The household's time zone, from the browser (stars and goals count on the family's own day). */
export function TimezoneField() {
  const [tz, setTz] = useState("UTC");
  useEffect(() => setTz(Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC"), []);
  return <input type="hidden" name="timezone" value={tz} />;
}
