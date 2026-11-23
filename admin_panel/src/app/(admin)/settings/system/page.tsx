import { requireAdmin } from "@/lib/auth";
import { settings } from "@/lib/data/admin";
import { canAny } from "@/lib/permissions";
import { ActionForm, Submit, TextField } from "@/components/form";
import { Card, dateTime, PageHeader, Table } from "@/components/ui";
import { saveSettingAction } from "../actions";

const GROUP: Record<string, string> = { goals: "Learning goals", content: "Content", media: "Media" };

export default async function System() {
  const { admin, db } = await requireAdmin(["admin.manage", "content.read"]);
  const rows = await settings(db);
  const edit = canAny(admin.permissions, ["admin.manage"]);
  const groups = [...new Set(rows.map((r) => r.key.split(".")[0]))];
  return (
    <>
      <PageHeader title="System settings" subtitle={edit ? "Checked by the database before they're saved." : "Only a super admin can change these."} />
      <div className="flex flex-col gap-s6">
        {groups.map((g) => (
          <Card key={g} title={GROUP[g] ?? g}>
            <Table head={["Setting", "Value", "Changed"]}>
              {rows.filter((r) => r.key.startsWith(`${g}.`)).map((r) => (
                <tr key={r.key}>
                  <td><span className="font-mono text-ui-small">{r.key}</span><div className="text-ui-small text-ui-text-muted">{r.description}</div></td>
                  <td>{edit ? (
                    <ActionForm action={saveSettingAction.bind(null, r.key)} className="!flex-row items-end">
                      <TextField name="value" label="Value" initial={Array.isArray(r.value) ? (r.value as string[]).join(", ") : String(r.value)} />
                      <Submit variant="secondary">Save</Submit>
                    </ActionForm>) : <code className="font-mono">{JSON.stringify(r.value)}</code>}</td>
                  <td className="text-ui-small">{dateTime(r.updatedAt)}</td>
                </tr>
              ))}
            </Table>
          </Card>
        ))}
      </div>
    </>
  );
}
