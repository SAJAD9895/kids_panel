import { requireAdmin } from "@/lib/auth";
import { listCategories, listSubjects } from "@/lib/data/content";
import { listAssets } from "@/lib/data/media";
import { ActivityForm } from "@/components/activity-form";
import { PageHeader } from "@/components/ui";
import { createActivity } from "../actions";

export default async function NewActivity() {
  const { db } = await requireAdmin(["content.write"]);
  const [subjects, categories, images] = await Promise.all([listSubjects(db), listCategories(db), listAssets(db, { kind: "image", status: "ready", pageSize: 200 })]);
  return (
    <>
      <PageHeader title="New activity" back={{ href: "/content/activities", label: "Activities" }}
        subtitle="It starts as a draft. Children only see it after it's reviewed, approved and published." />
      <ActivityForm action={createActivity} canWrite subjects={subjects.map((s) => ({ value: s.id, label: s.name }))}
        categories={categories.map((c) => ({ value: c.id, label: c.name }))} images={images.rows.map((i) => ({ value: i.id, label: i.path }))} />
    </>
  );
}
