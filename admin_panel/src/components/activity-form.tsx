"use client";
import { ActionForm, CheckField, SelectField, Submit, TextArea, TextField, type FormResult } from "./form";
import { ACTIVITY_TYPES } from "@/lib/validation";
import type { Activity } from "@/lib/data/content";

type Opt = { value: string; label: string };
type Action = (prev: FormResult, fd: FormData) => Promise<FormResult>;

export function ActivityForm({ action, a, subjects, categories, images, canWrite }: {
  action: Action; a?: Activity; subjects: Opt[]; categories: Opt[]; images: Opt[]; canWrite: boolean;
}) {
  return (
    <ActionForm action={action}>
      <fieldset disabled={!canWrite} className="grid gap-s5 md:grid-cols-2">
        <TextField name="title" label="Title" initial={a?.title} required maxLength={80} help="English. Short, for children and parents." />
        <TextField name="slug" label="Slug" initial={a?.slug} required help="Lower-case words with dashes; used in links. Don't change after publishing." />
        {a ? <input type="hidden" name="type" value={a.type} /> : (
          <SelectField name="type" label="Kind" initial="game" options={ACTIVITY_TYPES.map((t) => ({ value: t, label: t }))}
            help="Games use the learning engine; quizzes use questions and answers; the rest use media files." />
        )}
        <SelectField name="subjectId" label="Subject" initial={a?.subjectId} options={subjects} blank="— none —" />
        <SelectField name="categoryId" label="Category" initial={a?.categoryId} options={categories} blank="— none —" />
        <SelectField name="thumbnailAssetId" label="Thumbnail" initial={a?.thumbnailAssetId} options={images} blank="— none —" help="Upload pictures in the media library first." />
        <TextField name="ageMin" label="Youngest age (months)" type="number" min={0} max={144} initial={a?.ageMin ?? 36} />
        <TextField name="ageMax" label="Oldest age (months)" type="number" min={0} max={144} initial={a?.ageMax ?? 84} />
        <TextField name="difficulty" label="Difficulty (1–5)" type="number" min={1} max={5} initial={a?.difficulty ?? 1} />
        <TextField name="estimatedSeconds" label="Estimated time (seconds)" type="number" min={10} max={3600} initial={a?.estimatedSeconds} />
        <div className="md:col-span-2"><TextArea name="description" label="Description" initial={a?.description} rows={3} /></div>
        <TextField name="keywords" label="Search keywords" initial={a?.keywords} help="Words parents and children might search for." />
        <div className="flex flex-col gap-s3">
          <CheckField name="plusOnly" label="Plus only" initial={a?.plusOnly ?? false} />
          <CheckField name="freeEligible" label="Can be in the free daily set" initial={a?.freeEligible ?? true} />
        </div>
      </fieldset>
      {canWrite && <div><Submit>{a ? "Save details" : "Create"}</Submit></div>}
    </ActionForm>
  );
}
