import Link from "next/link";
import { requireAdmin } from "@/lib/auth";
import { listSubjects } from "@/lib/data/content";
import { listAssets } from "@/lib/data/media";
import { BADGE_RULES, listBadges, listRewardRules, type Badge } from "@/lib/data/rewards";
import { canAny } from "@/lib/permissions";
import { ActionForm, CheckField, ConfirmAction, SelectField, Submit, TextField } from "@/components/form";
import { Card, PageHeader, StatusBadge, Table } from "@/components/ui";
import { badgeStatus, saveBadgeAction, saveRule } from "./actions";

export default async function Rewards() {
  const { admin, db } = await requireAdmin(["content.read"]);
  const [badges, rules, subjects, images] = await Promise.all([listBadges(db), listRewardRules(db), listSubjects(db), listAssets(db, { kind: "image", status: "ready", pageSize: 200 })]);
  const w = canAny(admin.permissions, ["content.write"]);
  const ruleOpts = BADGE_RULES.map((r) => ({ value: r.rule, label: r.label }));
  const subjOpts = subjects.map((s) => ({ value: s.key, label: s.name }));
  const imgOpts = images.rows.map((i) => ({ value: i.id, label: i.path }));
  const form = (b?: Badge) => (
    <ActionForm action={saveBadgeAction.bind(null, b?.id)} resetOnOk={!b}>
      <div className="grid gap-s4 md:grid-cols-2">
        <TextField name="title" label="Title" initial={b?.title} /><TextField name="key" label="Key" initial={b?.key} help="badge-…, lower-case" />
        <TextField name="description" label="Description (when earned)" initial={b?.description} /><TextField name="howToEarn" label="How to earn it" initial={b?.howToEarn} />
        <SelectField name="rule" label="Earned when" initial={b?.rule} options={ruleOpts} />
        <TextField name="count" label="Number (N)" type="number" min={1} max={1000} initial={(b?.params.count ?? b?.params.days) as number | undefined} />
        <SelectField name="subject" label="Subject (explorer badges)" initial={b?.params.subject as string | undefined} options={subjOpts} blank="—" />
        <TextField name="bonusStars" label="Bonus stars (0–10)" type="number" min={0} max={10} initial={b?.bonusStars ?? 0} />
        <TextField name="sort" label="Order" type="number" initial={b?.sort ?? badges.length + 1} />
        <SelectField name="assetId" label="Artwork" initial={b?.assetId} options={imgOpts} />
      </div>
      <div><Submit>{b ? "Save badge" : "Add badge"}</Submit></div>
    </ActionForm>
  );
  return (
    <>
      <PageHeader title="Rewards" subtitle="Badges children can earn, and how many stars each event gives. Children's stars are never edited here." />
      <div className="flex flex-col gap-s6">
        <Card title="Reward rules (stars)">
          <Table head={["Event", "Stars", "On", "Explanation shown to parents", ""]}>
            {rules.map((r) => (
              <tr key={r.key}>
                <td className="font-mono text-ui-small">{r.key}</td>
                <td colSpan={w ? 4 : 1}>{w ? (
                  <ActionForm action={saveRule.bind(null, r.key)} className="!grid gap-s3 md:grid-cols-4 md:items-end">
                    <TextField name="stars" label="Stars (0–10)" type="number" min={0} max={10} initial={r.stars} />
                    <CheckField name="active" label="Active" initial={r.active} />
                    <TextField name="description" label="Explanation" initial={r.description} />
                    <Submit variant="secondary">Save</Submit>
                  </ActionForm>) : `${r.stars}${r.active ? "" : " (off)"} · ${r.description}`}</td>
              </tr>
            ))}
          </Table>
          <p className="mt-s3 text-ui-small text-ui-text-muted">Changes apply to new rewards only; stars already given stay. Default daily and weekly goals are in <Link className="text-ui-primary underline" href="/settings/system">System settings</Link>.</p>
        </Card>
        <Card title={`Badges (${badges.length})`}>
          <Table head={["Order", "Badge", "Earned when", "Bonus", "Children", "Status", ""]}>
            {badges.map((b) => (
              <tr key={b.id}>
                <td>{b.sort}</td>
                <td><strong>{b.title}</strong><div className="font-mono text-ui-caption text-ui-text-muted">{b.key}</div></td>
                <td className="text-ui-small">{BADGE_RULES.find((r) => r.rule === b.rule)?.label ?? b.rule} {Object.values(b.params).join(" ")}</td>
                <td>{b.bonusStars}</td><td>{b.earned}</td><td><StatusBadge status={b.status} /></td>
                <td>{w && <details><summary className="cursor-pointer text-ui-primary">Edit</summary><div className="mt-s3 flex flex-col gap-s3">{form(b)}
                  <div className="flex flex-wrap gap-s2">
                    {b.status !== "active" && <ConfirmAction action={badgeStatus.bind(null, b.id, "active")} label="Activate" title="Activate this badge?" message="Children can earn it from their next finished activity (needs a content manager)." confirm="Activate" />}
                    {b.status === "active" && <ConfirmAction action={badgeStatus.bind(null, b.id, "retired")} label="Retire" danger title="Retire this badge?" message="No one new can earn it. Children who have it keep it." confirm="Retire" />}
                  </div></div></details>}</td>
              </tr>
            ))}
          </Table>
          {w && <div className="mt-s6"><h3 className="mb-s3 text-ui-h3">New badge</h3>{form()}</div>}
        </Card>
      </div>
    </>
  );
}
