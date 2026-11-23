import { notFound } from "next/navigation";
import { ActionForm, ConfirmAction, Submit, TextField } from "@/components/form";
import { BuddyPicker } from "@/components/buddy-picker";
import { Card, LinkButton, Notice, PageHeader } from "@/components/ui";
import { listBuddies } from "@/lib/data/family";
import { listChildren, requireGrownUp } from "@/lib/session";
import { deleteChild, editChild } from "../../actions";

export default async function EditChild({ params, searchParams }: { params: Promise<{ id: string }>; searchParams: Promise<{ added?: string }> }) {
  const [{ id }, sp] = await Promise.all([params, searchParams]);
  const { db } = await requireGrownUp(`/parents/children/${id}`);
  const [kids, buddies] = await Promise.all([listChildren(db), listBuddies(db)]);
  const k = kids.find((c) => c.id === id); // RLS: only this family's children exist here
  if (!k) notFound();
  return (
    <>
      <PageHeader title={k.nickname} back={{ href: "/parents/children", label: "Children" }}
        actions={<><LinkButton href={`/parents/children/${id}/report`}>Report</LinkButton><LinkButton href={`/parents/children/${id}/controls`}>Controls</LinkButton></>} />
      {sp.added && <div className="mb-s5"><Notice tone="success">{k.nickname} is ready to play.</Notice></div>}
      <div className="grid gap-s6 lg:grid-cols-2">
        <Card title="Profile">
          <ActionForm action={editChild.bind(null, id)}>
            <TextField name="nickname" label="First name or nickname" initial={k.nickname} required maxLength={20} />
            <TextField name="birthYearMonth" label="Month and year of birth" type="month" initial={k.birthYearMonth} required help="Changing it changes which activities they see." />
            <BuddyPicker buddies={buddies} initial={k.avatarId} />
            <Submit>Save</Submit>
          </ActionForm>
        </Card>
        <Card title="Delete this profile">
          <p className="mb-s4 text-ui-body text-ui-text-muted">Deletes {k.nickname}&apos;s profile and everything they did: progress, stars, badges and reports. This can&apos;t be undone. You&apos;ll be asked to sign in again if you haven&apos;t recently.</p>
          <ConfirmAction action={deleteChild.bind(null, id)} label="Delete profile" danger title={`Delete ${k.nickname}'s profile?`} message="All their progress is removed straight away." confirm="Delete" />
        </Card>
      </div>
    </>
  );
}
