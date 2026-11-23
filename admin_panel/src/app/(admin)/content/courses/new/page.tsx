import { requireAdmin } from "@/lib/auth";
import { listCategories, listSubjects } from "@/lib/data/content";
import { listAssets } from "@/lib/data/media";
import { CourseForm } from "@/components/course-forms";
import { PageHeader } from "@/components/ui";
import { createCourse } from "../actions";

export default async function NewCourse() {
  const { db } = await requireAdmin(["content.write"]);
  const [s, c, i] = await Promise.all([listSubjects(db), listCategories(db), listAssets(db, { kind: "image", status: "ready", pageSize: 200 })]);
  return (
    <>
      <PageHeader title="New course" back={{ href: "/content/courses", label: "Courses" }} />
      <CourseForm action={createCourse} canWrite subjects={s.map((x) => ({ value: x.id, label: x.name }))}
        categories={c.map((x) => ({ value: x.id, label: x.name }))} images={i.rows.map((x) => ({ value: x.id, label: x.path }))} />
    </>
  );
}
