import { requireAdmin } from "@/lib/auth";
import { settings } from "@/lib/data/admin";
import { KINDS, listAssets } from "@/lib/data/media";
import { canAny } from "@/lib/permissions";
import { ActionForm, ConfirmAction, Submit, TextField } from "@/components/form";
import { Uploader } from "@/components/uploader";
import { Card, date, EmptyState, Filters, PageHeader, Pagination, StatusBadge, Table } from "@/components/ui";
import { finalizeUpload, retireAsset, saveLocale } from "./actions";

const sel = "rounded-md border border-ui-border-input bg-ui-bg px-s3 min-h-tap-ui";
const size = (b: number) => (b > 1048576 ? `${(b / 1048576).toFixed(1)} MB` : `${Math.ceil(b / 1024)} KB`);

export default async function Media({ searchParams }: { searchParams: Promise<{ q?: string; kind?: string; status?: string; page?: string }> }) {
  const sp = await searchParams;
  const { admin, db } = await requireAdmin(["content.read"]);
  const [res, cfg] = await Promise.all([listAssets(db, { q: sp.q, kind: sp.kind, status: sp.status, page: Number(sp.page) || 1 }), settings(db)]);
  const w = canAny(admin.permissions, ["content.write"]);
  const maxMb = Number(cfg.find((s) => s.key === "media.max_upload_mb")?.value ?? 200);
  const allowed = (cfg.find((s) => s.key === "media.allowed_types")?.value as string[]) ?? [];
  return (
    <>
      <PageHeader title="Media library" subtitle="Videos, songs, story pages, thumbnails, artwork and captions." />
      {w && <Card title="Upload" className="mb-s6"><Uploader userId={admin.userId} maxMb={maxMb} allowed={allowed} finalize={finalizeUpload} /></Card>}
      <Filters path="/media">
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Path contains</span><input name="q" defaultValue={sp.q} className={sel} /></label>
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Kind</span><select name="kind" defaultValue={sp.kind ?? ""} className={sel}><option value="">All</option>{KINDS.map((k) => <option key={k}>{k}</option>)}</select></label>
        <label className="flex flex-col gap-s2"><span className="text-ui-small">Status</span><select name="status" defaultValue={sp.status ?? ""} className={sel}><option value="">All</option>{["ready", "processing", "failed", "retired"].map((s) => <option key={s}>{s}</option>)}</select></label>
      </Filters>
      {res.rows.length === 0 ? <EmptyState title="No files match" /> : (
        <Table head={["File", "Kind", "Size", "Details", "Language", "Status", "Added", ""]}>
          {res.rows.map((m) => (
            <tr key={m.id}>
              <td className="max-w-ui-form-w break-all font-mono text-ui-small">{m.bucket}/{m.path}</td>
              <td>{m.kind}</td>
              <td className="whitespace-nowrap text-ui-small">{size(m.bytes)}</td>
              <td className="text-ui-small">{m.width ? `${m.width}×${m.height}` : ""}{m.durationMs ? ` ${(m.durationMs / 1000).toFixed(0)} s` : ""}</td>
              <td>{w ? (
                <ActionForm action={saveLocale.bind(null, m.id)} className="!flex-row items-end !gap-s2">
                  <TextField name="locale" label="Language" initial={m.locale ?? ""} /><Submit variant="secondary">Set</Submit>
                </ActionForm>) : m.locale ?? "any"}</td>
              <td><StatusBadge status={m.status} /></td>
              <td className="whitespace-nowrap text-ui-small">{date(m.createdAt)}</td>
              <td>{w && (m.status === "retired"
                ? <ConfirmAction action={retireAsset.bind(null, m.id, false)} label="Restore" title="Restore this file?" message="It can be used again." confirm="Restore" />
                : <ConfirmAction action={retireAsset.bind(null, m.id, true)} label="Retire" title="Retire this file?" message="Content already using it keeps working only if a content manager confirms; nothing new can use it." confirm="Retire" danger />)}</td>
            </tr>
          ))}
        </Table>
      )}
      <Pagination path="/media" page={res.page} pageSize={res.pageSize} total={res.total} params={{ q: sp.q, kind: sp.kind, status: sp.status }} />
    </>
  );
}
