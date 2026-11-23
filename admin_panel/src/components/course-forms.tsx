"use client";
import { ActionForm, CheckField, SelectField, Submit, TextArea, TextField, type FormResult } from "./form";
import { STAGES, STAGE_AGES } from "@/lib/validation";
import type { Course, Lesson } from "@/lib/data/content";

type Opt = { value: string; label: string };
type Action = (prev: FormResult, fd: FormData) => Promise<FormResult>;

export function CourseForm({ action, c, subjects, categories, images, canWrite }: { action: Action; c?: Course; subjects: Opt[]; categories: Opt[]; images: Opt[]; canWrite: boolean }) {
  return (
    <ActionForm action={action}>
      <fieldset disabled={!canWrite} className="grid gap-s5 md:grid-cols-2">
        <TextField name="title" label="Course title" initial={c?.title} required maxLength={80} />
        <TextField name="slug" label="Slug" initial={c?.slug} required />
        <SelectField name="subjectId" label="Subject" initial={c?.subjectId} options={subjects} blank="— none —" />
        <SelectField name="categoryId" label="Category" initial={c?.categoryId} options={categories} blank="— none —" />
        <SelectField name="stage" label="Age range (stage)" initial={c?.stage ?? "preschool"}
          options={STAGES.map((s) => ({ value: s, label: `${s} (${STAGE_AGES[s]})` }))} help="The app suggests the course to children of this stage." />
        <TextField name="difficulty" label="Difficulty (1–5)" type="number" min={1} max={5} initial={c?.difficulty ?? 1} />
        <SelectField name="coverAssetId" label="Thumbnail" initial={c?.coverAssetId} options={images} blank="— none —" />
        <TextField name="sort" label="Order in course lists" type="number" min={0} max={999} initial={c?.sort ?? 0} help="Lower comes first." />
        <div className="md:col-span-2"><TextArea name="description" label="Description" initial={c?.description} rows={3} /></div>
        <div className="md:col-span-2"><TextArea name="objectives" label="Learning objectives (one per line)" initial={c?.objectives.join("\n")} rows={4} help="Up to 8, e.g. “Recognise the letters a to h”." /></div>
        <CheckField name="plusOnly" label="Plus only" initial={c?.plusOnly ?? true} />
      </fieldset>
      {canWrite && <div><Submit>{c ? "Save course" : "Create course"}</Submit></div>}
    </ActionForm>
  );
}

export function LessonForm({ action, l, siblings, images, canWrite }: { action: Action; l: Lesson; siblings: Opt[]; images: Opt[]; canWrite: boolean }) {
  return (
    <ActionForm action={action}>
      <fieldset disabled={!canWrite} className="grid gap-s5 md:grid-cols-2">
        <TextField name="title" label="Lesson title" initial={l.title} required maxLength={80} />
        <TextField name="estimatedMinutes" label="Estimated duration (minutes)" type="number" min={1} max={120} initial={l.estimatedMinutes} />
        <div className="md:col-span-2"><TextArea name="description" label="Description" initial={l.description} rows={2} /></div>
        <div className="md:col-span-2"><TextArea name="objectives" label="Learning objectives (one per line)" initial={l.objectives.join("\n")} rows={3} /></div>
        <div className="md:col-span-2"><TextArea name="instructions" label="Instructions for the grown-up" initial={l.instructions} rows={3} help="Shown to parents; children get spoken prompts in each activity." /></div>
        <SelectField name="coverAssetId" label="Island picture" initial={l.coverAssetId} options={images} blank="— none —" />
        <fieldset className="flex flex-col gap-s2 md:col-span-2">
          <legend className="text-ui-body-strong">Prerequisites (must be finished first)</legend>
          <p className="text-ui-small text-ui-text-muted">Islands already open one after another; tick any other lessons of this course that must be done first. The app enforces this.</p>
          {siblings.length === 0 && <p className="text-ui-small text-ui-text-muted">No other lessons in this course yet.</p>}
          {siblings.map((s) => (
            <label key={s.value} className="flex items-center gap-s3">
              <input type="checkbox" name="prerequisites" value={s.value} defaultChecked={l.prerequisites.includes(s.value)} className="size-icon-md accent-ui-primary" />{s.label}
            </label>
          ))}
        </fieldset>
      </fieldset>
      {canWrite && <div><Submit>Save lesson</Submit></div>}
    </ActionForm>
  );
}
