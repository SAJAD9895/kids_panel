"use client";
// Forms backed by server actions. Values come back with every result, so a failed save keeps
// what was typed; field errors show under their fields.
import { createContext, useActionState, useContext, useEffect, useId, useRef, useState, type ReactNode } from "react";
import { useFormStatus } from "react-dom";

export type FormResult = { ok?: string; error?: string; fieldErrors?: Record<string, string>; values?: Record<string, string> };
type Action = (prev: FormResult, fd: FormData) => Promise<FormResult>;
const Ctx = createContext<FormResult>({});

export function ActionForm({ action, children, className = "", resetOnOk = false }: { action: Action; children: ReactNode; className?: string; resetOnOk?: boolean }) {
  const [state, formAction] = useActionState(action, {});
  const ref = useRef<HTMLFormElement>(null);
  useEffect(() => {
    if (resetOnOk && state.ok) ref.current?.reset();
  }, [state, resetOnOk]);
  return (
    <Ctx.Provider value={state}>
      <form ref={ref} action={formAction} className={`flex flex-col gap-s5 ${className}`} noValidate>
        {state.error && <p role="alert" className="rounded-md bg-ui-danger-soft p-s4 text-ui-body text-ui-danger">{state.error}</p>}
        {state.ok && !state.error && <p role="status" className="rounded-md bg-ui-success-soft p-s4 text-ui-body text-ui-success">{state.ok}</p>}
        {children}
      </form>
    </Ctx.Provider>
  );
}

const useField = (name: string, initial?: string | number | null) => {
  const s = useContext(Ctx);
  return { value: s.values?.[name] ?? (initial == null ? "" : String(initial)), error: s.fieldErrors?.[name] };
};

const inputCls = "w-full rounded-md border border-ui-border-input bg-ui-bg px-s4 min-h-tap-ui text-ui-body aria-[invalid=true]:border-ui-danger";

function Wrap({ id, label, help, error, children }: { id: string; label: string; help?: string; error?: string; children: ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col gap-s2">
      <label htmlFor={id} className="text-ui-body-strong">{label}</label>
      {children}
      {help && <p id={`${id}-help`} className="text-ui-small text-ui-text-muted">{help}</p>}
      {error && <p id={`${id}-err`} className="text-ui-small text-ui-danger">{error}</p>}
    </div>
  );
}

type Common = { name: string; label: string; help?: string; initial?: string | number | null; required?: boolean };

export function TextField({ name, label, help, initial, required, type = "text", ...rest }: Common & { type?: string; placeholder?: string; min?: number; max?: number; maxLength?: number }) {
  const f = useField(name, initial);
  const id = `f-${name}${useId().replace(/:/g, "")}`; // unique: two forms on a page can share a field name
  return (
    <Wrap id={id} label={label} help={help} error={f.error}>
      <input id={id} name={name} type={type} defaultValue={f.value} key={f.value} required={required} aria-invalid={!!f.error}
        aria-describedby={[help && `${id}-help`, f.error && `${id}-err`].filter(Boolean).join(" ") || undefined} className={inputCls} {...rest} />
    </Wrap>
  );
}

export function TextArea({ name, label, help, initial, rows = 4, mono = false }: Common & { rows?: number; mono?: boolean }) {
  const f = useField(name, initial);
  const id = `f-${name}${useId().replace(/:/g, "")}`; // unique: two forms on a page can share a field name
  return (
    <Wrap id={id} label={label} help={help} error={f.error}>
      <textarea id={id} name={name} rows={rows} defaultValue={f.value} key={f.value} aria-invalid={!!f.error}
        className={`${inputCls} py-s3 ${mono ? "font-mono text-ui-small" : ""}`} />
    </Wrap>
  );
}

export function SelectField({ name, label, help, initial, options, blank }: Common & { options: { value: string; label: string }[]; blank?: string }) {
  const f = useField(name, initial);
  const id = `f-${name}${useId().replace(/:/g, "")}`; // unique: two forms on a page can share a field name
  return (
    <Wrap id={id} label={label} help={help} error={f.error}>
      <select id={id} name={name} defaultValue={f.value} key={f.value} aria-invalid={!!f.error} className={inputCls}>
        {blank !== undefined && <option value="">{blank}</option>}
        {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    </Wrap>
  );
}

export function CheckField({ name, label, help, initial }: { name: string; label: string; help?: string; initial?: boolean }) {
  const s = useContext(Ctx);
  const checked = s.values ? s.values[name] === "on" : !!initial;
  return (
    <label className="flex items-start gap-s3">
      <input type="checkbox" name={name} defaultChecked={checked} key={String(checked)} className="mt-s2 size-icon-md accent-ui-primary" />
      <span>
        <span className="text-ui-body-strong">{label}</span>
        {help && <span className="block text-ui-small text-ui-text-muted">{help}</span>}
      </span>
    </label>
  );
}

export function Submit({ children = "Save", variant = "primary" }: { children?: ReactNode; variant?: "primary" | "danger" | "secondary" }) {
  const { pending } = useFormStatus();
  const v = variant === "danger" ? "bg-ui-danger text-ui-on-danger" : variant === "secondary" ? "bg-ui-bg text-ui-text border border-ui-border-input" : "bg-ui-primary text-ui-on-primary hover:bg-ui-primary-hover";
  return (
    <button type="submit" disabled={pending} aria-busy={pending}
      className={`inline-flex min-h-tap-ui items-center justify-center rounded-md px-s5 text-ui-body-strong disabled:opacity-50 ${v}`}>
      {pending ? "Working…" : children}
    </button>
  );
}

/** A button that asks first (and optionally for a reason) before running its action. */
export function ConfirmAction({ action, label, title, message, confirm = "Confirm", danger = false, reason, hidden }: {
  action: Action; label: string; title: string; message: string; confirm?: string; danger?: boolean; reason?: string; hidden?: Record<string, string>;
}) {
  const [open, setOpen] = useState(false);
  const [state, formAction] = useActionState(action, {});
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    if (open) dialog.current?.showModal();
    else dialog.current?.close();
  }, [open]);
  useEffect(() => {
    if (state.ok) setOpen(false);
  }, [state]);
  return (
    <>
      <button type="button" onClick={() => setOpen(true)}
        className={`inline-flex min-h-tap-ui items-center rounded-md px-s5 text-ui-body-strong ${danger ? "border border-ui-danger text-ui-danger hover:bg-ui-danger-soft" : "border border-ui-border-input bg-ui-bg hover:bg-ui-surface"}`}>
        {label}
      </button>
      {state.error && !open && <p role="alert" className="text-ui-small text-ui-danger">{state.error}</p>}
      {state.ok && !open && <p role="status" className="text-ui-small text-ui-success">{state.ok}</p>}
      <dialog ref={dialog} onClose={() => setOpen(false)} aria-labelledby={`${label}-t`}
        className="m-auto w-full max-w-ui-form-w rounded-lg bg-ui-bg p-s7 shadow-pop backdrop:bg-ui-text/50">
        <form action={formAction} className="flex flex-col gap-s5">
          <h2 id={`${label}-t`} className="text-ui-h3">{title}</h2>
          <p className="text-ui-body text-ui-text-muted">{message}</p>
          {Object.entries(hidden ?? {}).map(([k, v]) => <input key={k} type="hidden" name={k} value={v} />)}
          {reason && (
            <label className="flex flex-col gap-s2">
              <span className="text-ui-body-strong">{reason}</span>
              <textarea name="reason" required rows={3} className="rounded-md border border-ui-border-input p-s3 text-ui-body" />
            </label>
          )}
          {state.error && <p role="alert" className="text-ui-small text-ui-danger">{state.error}</p>}
          <div className="flex justify-end gap-s3">
            <button type="button" onClick={() => setOpen(false)} className="min-h-tap-ui rounded-md border border-ui-border-input px-s5">Cancel</button>
            <Submit variant={danger ? "danger" : "primary"}>{confirm}</Submit>
          </div>
        </form>
      </dialog>
    </>
  );
}
