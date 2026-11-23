import Link from "next/link";
import { redirect } from "next/navigation";
import { ActionForm, CheckField, SelectField, Submit, TextField } from "@/components/form";
import { BuddyPicker } from "@/components/buddy-picker";
import { listBuddies } from "@/lib/data/family";
import { currentUser, familyOf } from "@/lib/session";
import { createFamily } from "../../actions";
import { AuthShell } from "../../shell";
import { TimezoneField } from "./timezone";

const COUNTRIES = [["AE", "United Arab Emirates"], ["AU", "Australia"], ["CA", "Canada"], ["DE", "Germany"], ["ES", "Spain"], ["FR", "France"], ["GB", "United Kingdom"], ["IE", "Ireland"], ["IN", "India"], ["NZ", "New Zealand"], ["SA", "Saudi Arabia"], ["US", "United States"]];

export default async function FamilySetup() {
  const { db, user } = await currentUser();
  if (!user) redirect("/sign-up");
  if (await familyOf(db, user.id, user.email ?? "")) redirect("/who");
  const buddies = await listBuddies(db);
  return (
    <AuthShell title="About your child" lead="Step 3 of 3. Just a first name or nickname and the month they were born: we use it to pick the right activities. Nothing else about your child is needed."
      foot={<>Signed in as {user.email}. <Link href="/sign-in" className="text-ui-primary underline">Not you?</Link></>}>
      <ActionForm action={createFamily}>
        <TimezoneField />
        <TextField name="nickname" label="Child's first name or nickname" required maxLength={20} help="Up to 20 letters. Shown only inside your family." />
        <TextField name="birthYearMonth" label="Month and year of birth" type="month" required help="For ages 1 to 12. We never ask for the day." />
        <BuddyPicker buddies={buddies} />
        <SelectField name="country" label="Country (optional)" blank="— choose —" options={COUNTRIES.map(([value, label]) => ({ value, label }))} />
        <fieldset className="flex flex-col gap-s3 rounded-md bg-ui-surface p-s4">
          <legend className="text-ui-body-strong">Your consent, as the parent or guardian</legend>
          <CheckField name="terms" label="I accept the terms of use" />
          <CheckField name="privacy" label="I've read the privacy policy" />
          <CheckField name="childData" label="I consent to saving my child's learning progress (games played, stars, lessons) so we can show it to me and pick what comes next" />
          <CheckField name="marketing" label="Send me occasional tips and news (optional)" />
        </fieldset>
        <Submit>Create our family</Submit>
      </ActionForm>
    </AuthShell>
  );
}
