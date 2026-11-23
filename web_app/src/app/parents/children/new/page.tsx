import { ActionForm, Submit, TextField } from "@/components/form";
import { BuddyPicker } from "@/components/buddy-picker";
import { Card, PageHeader } from "@/components/ui";
import { listBuddies } from "@/lib/data/family";
import { requireGrownUp } from "@/lib/session";
import { addChild } from "../../actions";

export default async function NewChild() {
  const { db } = await requireGrownUp("/parents/children/new");
  const buddies = await listBuddies(db);
  return (
    <>
      <PageHeader title="Add a child" back={{ href: "/parents/children", label: "Children" }} subtitle="Only a name or nickname and the month of birth. Your plan decides how many children you can add." />
      <Card className="max-w-ui-form-w">
        <ActionForm action={addChild}>
          <TextField name="nickname" label="First name or nickname" required maxLength={20} />
          <TextField name="birthYearMonth" label="Month and year of birth" type="month" required />
          <BuddyPicker buddies={buddies} />
          <Submit>Add child</Submit>
        </ActionForm>
      </Card>
    </>
  );
}
