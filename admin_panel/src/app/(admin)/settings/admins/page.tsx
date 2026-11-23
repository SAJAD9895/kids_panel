import { requireAdmin } from "@/lib/auth";
import { adminUsers, roleMatrix } from "@/lib/data/admin";
import { ROLE_INFO } from "@/lib/permissions";
import { ActionForm, ConfirmAction, Submit, TextField } from "@/components/form";
import { Card, date, PageHeader, StatusBadge, Table } from "@/components/ui";
import { adminStatus, saveRoles } from "../actions";

function RoleChecks({ roles, current }: { roles: string[]; current: string[] }) {
  return (
    <fieldset className="flex flex-col gap-s2"><legend className="text-ui-body-strong">Roles</legend>
      {roles.map((r) => (
        <label key={r} className="flex items-start gap-s3">
          <input type="checkbox" name="roles" value={r} defaultChecked={current.includes(r)} className="mt-s2 size-icon-md accent-ui-primary" />
          <span><span className="text-ui-body-strong">{ROLE_INFO[r]?.label ?? r}</span><span className="block text-ui-small text-ui-text-muted">{ROLE_INFO[r]?.summary}</span></span>
        </label>
      ))}
    </fieldset>
  );
}

export default async function Admins() {
  const { admin, db } = await requireAdmin(["admin.manage"]);
  const [users, m] = await Promise.all([adminUsers(db), roleMatrix(db)]);
  const roles = m.roles.map((r) => r.key);
  return (
    <>
      <PageHeader title="Admin users" subtitle="Give staff the roles they need. You can't change your own roles or status, and there's always at least one active super admin." />
      <div className="flex flex-col gap-s6">
        <Card title="Admins">
          <Table head={["Email", "Roles", "Status", "Since", ""]}>
            {users.map((u) => (
              <tr key={u.userId}>
                <td>{u.email}{u.userId === admin.userId ? " (you)" : ""}</td>
                <td className="text-ui-small">{u.roles.map((r) => ROLE_INFO[r]?.label ?? r).join(", ") || "none"}</td>
                <td><StatusBadge status={u.status} /></td><td className="text-ui-small">{date(u.since)}</td>
                <td>{u.userId !== admin.userId && (
                  <details><summary className="cursor-pointer text-ui-primary">Change</summary>
                    <div className="mt-s3 flex flex-col gap-s3">
                      <ActionForm action={saveRoles}><input type="hidden" name="email" value={u.email} /><RoleChecks roles={roles} current={u.roles} /><Submit>Save roles</Submit></ActionForm>
                      {u.status === "active"
                        ? <ConfirmAction action={adminStatus.bind(null, u.userId, "suspended")} label="Suspend" danger title={`Suspend ${u.email}?`} message="They lose admin access at once (their roles are kept)." confirm="Suspend" />
                        : <ConfirmAction action={adminStatus.bind(null, u.userId, "active")} label="Reactivate" title={`Reactivate ${u.email}?`} message="They get their roles back." confirm="Reactivate" />}
                    </div>
                  </details>)}</td>
              </tr>
            ))}
          </Table>
        </Card>
        <Card title="Add an admin">
          <ActionForm action={saveRoles} resetOnOk>
            <TextField name="email" label="Email" type="email" help="They need an account already (they sign up, then you add them). They'll set up an authenticator at first sign-in." />
            <RoleChecks roles={roles} current={[]} />
            <div><Submit>Add admin</Submit></div>
          </ActionForm>
        </Card>
        <Card title="Roles and permissions">
          <Table head={["Permission", ...m.roles.map((r) => ROLE_INFO[r.key]?.label ?? r.key)]}>
            {m.permissions.map((p) => (
              <tr key={p.key}><td><span className="font-mono text-ui-small">{p.key}</span><div className="text-ui-caption text-ui-text-muted">{p.description}</div></td>
                {m.roles.map((r) => <td key={r.key} className="text-center">{m.grants.has(`${r.key}|${p.key}`) ? <span aria-label="yes">✓</span> : <span aria-label="no" className="text-ui-text-muted">–</span>}</td>)}</tr>
            ))}
          </Table>
          <p className="mt-s3 text-ui-small text-ui-text-muted">Roles and their permissions are part of the database migrations (reviewed changes), not edited here.</p>
        </Card>
      </div>
    </>
  );
}
