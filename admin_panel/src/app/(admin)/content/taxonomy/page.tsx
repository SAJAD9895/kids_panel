import { requireAdmin } from "@/lib/auth";
import { listCategories, listSubjects } from "@/lib/data/content";
import { listAssets } from "@/lib/data/media";
import { canAny } from "@/lib/permissions";
import { ActionForm, ConfirmAction, SelectField, Submit, TextField } from "@/components/form";
import { Card, EmptyState, PageHeader, StatusBadge, Table } from "@/components/ui";
import { removeCategory, removeSubject, saveCategory, saveSubject, toggleCategory } from "./actions";

export default async function Taxonomy() {
  const { admin, db } = await requireAdmin(["content.read"]);
  const [subjects, cats, icons] = await Promise.all([listSubjects(db), listCategories(db), listAssets(db, { kind: "image", status: "ready", pageSize: 200 })]);
  const w = canAny(admin.permissions, ["content.write"]);
  const parents = cats.filter((c) => !c.parentId);
  const iconOpts = icons.rows.map((i) => ({ value: i.id, label: i.path }));
  const name = (id: string | null) => cats.find((c) => c.id === id)?.name ?? "";
  return (
    <>
      <PageHeader title="Subjects and categories" subtitle="Subjects organise learning (Letters, Numbers…). Categories group content in the app (Bedtime, Music time…) and can be switched off." />
      <div className="flex flex-col gap-s6">
        <Card title="Subjects">
          {subjects.length === 0 ? <EmptyState title="No subjects yet" /> : (
            <Table head={["Order", "Name", "Key", "Activities", ""]}>
              {subjects.map((s) => (
                <tr key={s.id}>
                  <td>{s.sort}</td><td>{s.name}</td><td className="font-mono text-ui-small">{s.key}</td><td>{s.activities}</td>
                  <td>{w && (
                    <details><summary className="cursor-pointer text-ui-primary">Edit</summary>
                      <div className="mt-s3 flex flex-col gap-s3">
                        <ActionForm action={saveSubject.bind(null, s.id)}>
                          <TextField name="name" label="Name" initial={s.name} /><TextField name="key" label="Key" initial={s.key} />
                          <TextField name="sort" label="Order" type="number" initial={s.sort} /><Submit>Save</Submit>
                        </ActionForm>
                        <ConfirmAction action={removeSubject.bind(null, s.id)} label="Delete" danger title={`Delete ${s.name}?`}
                          message={s.activities ? "It's used by activities, so it can't be deleted." : "It isn't used by any activity."} confirm="Delete" />
                      </div>
                    </details>)}</td>
                </tr>
              ))}
            </Table>
          )}
          {w && (
            <div className="mt-s5"><ActionForm action={saveSubject.bind(null, undefined)} resetOnOk>
              <div className="grid gap-s4 md:grid-cols-3"><TextField name="name" label="New subject" /><TextField name="key" label="Key" help="e.g. numbers" /><TextField name="sort" label="Order" type="number" initial={subjects.length + 1} /></div>
              <div><Submit>Add subject</Submit></div>
            </ActionForm></div>
          )}
        </Card>

        <Card title="Categories">
          <Table head={["Order", "Name", "Inside", "Key", "Icon", "Items", "Status", ""]}>
            {[...parents, ...cats.filter((c) => c.parentId)].map((c) => (
              <tr key={c.id}>
                <td>{c.sort}</td>
                <td>{c.parentId ? "↳ " : ""}{c.name}</td>
                <td className="text-ui-small">{c.parentId ? name(c.parentId) : "—"}</td>
                <td className="font-mono text-ui-small">{c.key}</td>
                <td className="break-all text-ui-small">{c.iconPath ?? "—"}</td>
                <td>{c.activities}</td>
                <td><StatusBadge status={c.status === "published" ? "active" : c.status === "retired" ? "retired" : "draft"} /></td>
                <td>{w && (
                  <details><summary className="cursor-pointer text-ui-primary">Edit</summary>
                    <div className="mt-s3 flex flex-col gap-s3">
                      <ActionForm action={saveCategory.bind(null, c.id)}>
                        <TextField name="name" label="Name" initial={c.name} /><TextField name="key" label="Key" initial={c.key} />
                        <TextField name="sort" label="Order" type="number" initial={c.sort} />
                        <SelectField name="parentId" label="Inside (sub-category of)" initial={c.parentId} blank="— top level —" options={parents.filter((p) => p.id !== c.id).map((p) => ({ value: p.id, label: p.name }))} />
                        <SelectField name="iconAssetId" label="Icon or picture" initial={c.iconAssetId} blank="— none —" options={iconOpts} />
                        <Submit>Save</Submit>
                      </ActionForm>
                      {c.status === "published"
                        ? <ConfirmAction action={toggleCategory.bind(null, c.id, false)} label="Disable" title={`Disable ${c.name}?`} message="Children stop seeing this category's row. Its activities stay published." confirm="Disable" />
                        : <ConfirmAction action={toggleCategory.bind(null, c.id, true)} label="Enable" title={`Enable ${c.name}?`} message="The category shows in the app (needs a content manager)." confirm="Enable" />}
                      <ConfirmAction action={removeCategory.bind(null, c.id)} label="Delete" danger title={`Delete ${c.name}?`} message="Only possible when nothing uses it." confirm="Delete" />
                    </div>
                  </details>)}</td>
              </tr>
            ))}
          </Table>
          {w && (
            <div className="mt-s5"><ActionForm action={saveCategory.bind(null, undefined)} resetOnOk>
              <div className="grid gap-s4 md:grid-cols-3">
                <TextField name="name" label="New category" /><TextField name="key" label="Key" help="e.g. bedtime" />
                <TextField name="sort" label="Order" type="number" initial={cats.length + 1} />
                <SelectField name="parentId" label="Inside (optional)" blank="— top level —" options={parents.map((p) => ({ value: p.id, label: p.name }))} />
                <SelectField name="iconAssetId" label="Icon or picture" blank="— none —" options={iconOpts} />
              </div>
              <div><Submit>Add category</Submit></div>
              <p className="text-ui-small text-ui-text-muted">New categories start as drafts (hidden) until enabled.</p>
            </ActionForm></div>
          )}
        </Card>
      </div>
    </>
  );
}
