// Loading skeletons, shown by the route `loading.tsx` files the moment a link is tapped, while the
// server loads the page's data. Shapes follow the real pages (cards, shelves, the player stage)
// so nothing jumps when the content arrives. Server components only: no client JavaScript.
// Bones are hidden from screen readers; each skeleton announces one "Loading…" instead.
import type { ReactNode } from "react";

/** One grey placeholder block. `kids` picks the child-zone palette. */
export function Bone({ className = "", kids = false }: { className?: string; kids?: boolean }) {
  return <span aria-hidden className={`block animate-pulse motion-reduce:animate-none ${kids ? "bg-kids-line" : "bg-ui-border"} ${className}`} />;
}

/** Wraps a skeleton: announced once as "Loading…", busy for assistive tech. */
export function Loading({ children, label = "Loading…", className = "" }: { children: ReactNode; label?: string; className?: string }) {
  return (
    <div role="status" aria-live="polite" aria-busy="true" className={className}>
      <span className="sr-only">{label}</span>
      {children}
    </div>
  );
}

// ---------------------------------------------------------------- child zone

/** An ActivityCard's shape: art on top, kind and title below. */
export function KidsCardSkeleton() {
  return (
    <div aria-hidden className="flex w-kids-card-w shrink-0 flex-col overflow-hidden rounded-xl bg-kids-surface shadow-kid-raised xl:w-auto">
      <Bone kids className="h-kids-card-art-h" />
      <div className="flex flex-col gap-s2 p-s3">
        <Bone kids className="h-s3 w-1/3 rounded-pill" />
        <Bone kids className="h-s4 w-4/5 rounded-pill" />
      </div>
    </div>
  );
}

/** A Shelf: heading and a row of cards (a grid on wide screens, like the real one). */
export function KidsShelfSkeleton({ count = 5 }: { count?: number }) {
  return (
    <section aria-hidden className="flex flex-col gap-s3">
      <Bone kids className="mx-s1 h-s6 w-2/5 max-w-ui-form-w rounded-pill" />
      <div className="-mx-s4 flex gap-s4 overflow-hidden px-s4 pb-s3 xl:mx-0 xl:grid xl:grid-cols-[repeat(auto-fill,minmax(var(--spacing-kids-card-w),1fr))] xl:px-0">
        {Array.from({ length: count }, (_, i) => <KidsCardSkeleton key={i} />)}
      </div>
    </section>
  );
}

/** Child home and the section pages (learn, games, watch, listen): a greeting band and shelves. */
export function KidsHomeSkeleton() {
  return (
    <Loading className="flex flex-col gap-s8">
      <div aria-hidden className="flex flex-col gap-s4 rounded-xl bg-kids-me-soft p-s6 md:flex-row md:items-center md:justify-between">
        <div className="flex flex-col gap-s3">
          <Bone kids className="h-s8 w-s12 rounded-pill md:w-ui-sidebar-w" />
          <Bone kids className="h-s5 w-4/5 rounded-pill" />
        </div>
        <div className="flex flex-col gap-s2 md:w-ui-sidebar-w">
          <Bone kids className="h-s5 w-1/2 rounded-pill" />
          <Bone kids className="h-s3 w-full rounded-pill" />
        </div>
      </div>
      <KidsShelfSkeleton />
      <KidsShelfSkeleton count={4} />
    </Loading>
  );
}

/** A course, path, subject or "my page": a big banner, then its rows. */
export function KidsDetailSkeleton() {
  return (
    <Loading className="flex flex-col gap-s8">
      <div aria-hidden className="flex flex-col gap-s3">
        <Bone kids className="h-s4 w-s12 rounded-pill" />
        <Bone kids className="h-kids-hero-h w-full rounded-xl" />
      </div>
      <KidsShelfSkeleton />
    </Loading>
  );
}

/** A game, video, song or story: the stage with its controls underneath. */
export function KidsPlayerSkeleton() {
  return (
    <Loading className="mx-auto flex w-full max-w-kids-video-w flex-col gap-s5">
      <div aria-hidden className="flex items-center justify-between gap-s4">
        <Bone kids className="h-s6 w-2/5 rounded-pill" />
        <Bone kids className="size-tap-kids rounded-pill" />
      </div>
      <Bone kids className="aspect-video w-full rounded-xl" />
      <div aria-hidden className="flex justify-center gap-s4">
        <Bone kids className="size-tap-kids rounded-pill" />
        <Bone kids className="size-tap-kids rounded-pill" />
        <Bone kids className="size-tap-kids rounded-pill" />
      </div>
    </Loading>
  );
}

/** "Who's playing?": the buddy tiles. This page has no layout, so it draws the whole screen. */
export function WhoSkeleton() {
  return (
    <Loading className="kids flex min-h-screen flex-col items-center px-s5 py-s9">
      <Bone kids className="h-s10 w-3/5 max-w-ui-form-w rounded-pill" />
      <div aria-hidden className="mt-s8 grid w-full max-w-ui-content-max grid-cols-2 gap-s5 sm:grid-cols-3 lg:grid-cols-4">
        {Array.from({ length: 3 }, (_, i) => (
          <div key={i} className="flex flex-col items-center gap-s3 rounded-xl bg-kids-surface p-s5 shadow-kid-raised">
            <Bone kids className="size-kids-buddy-tile rounded-pill" />
            <Bone kids className="h-s6 w-2/3 rounded-pill" />
          </div>
        ))}
      </div>
    </Loading>
  );
}

// ---------------------------------------------------------------- grown-ups

function HeaderSkeleton() {
  return (
    <div aria-hidden className="mb-s7 flex flex-wrap items-end justify-between gap-s5">
      <div className="flex min-w-0 flex-1 flex-col gap-s3">
        <Bone className="h-s8 w-2/5 max-w-ui-form-w rounded-md" />
        <Bone className="h-s4 w-3/5 max-w-ui-form-w rounded-md" />
      </div>
      <Bone className="min-h-tap-ui w-s12 rounded-md" />
    </div>
  );
}

function CardSkeleton({ lines = 3 }: { lines?: number }) {
  return (
    <div aria-hidden className="rounded-lg border border-ui-border bg-ui-surface-raised p-s6 shadow-card">
      <div className="flex items-center gap-s4">
        <Bone className="size-tap-kids shrink-0 rounded-pill" />
        <div className="flex flex-1 flex-col gap-s2">
          <Bone className="h-s5 w-2/5 rounded-md" />
          <Bone className="h-s3 w-1/4 rounded-md" />
        </div>
      </div>
      <div className="mt-s5 grid grid-cols-2 gap-s3 sm:grid-cols-4">
        {Array.from({ length: 4 }, (_, i) => <Bone key={i} className="h-s10 rounded-md" />)}
      </div>
      <div className="mt-s5 flex flex-col gap-s3">
        {Array.from({ length: lines }, (_, i) => <Bone key={i} className={`h-s4 rounded-md ${i % 2 ? "w-3/4" : "w-full"}`} />)}
      </div>
    </div>
  );
}

/** Grown-up pages: title, then cards (the family overview, a child, settings forms). */
export function ParentPageSkeleton({ cards = 2 }: { cards?: number }) {
  return (
    <Loading>
      <HeaderSkeleton />
      <div className="grid gap-s5 xl:grid-cols-2">
        {Array.from({ length: cards }, (_, i) => <CardSkeleton key={i} />)}
      </div>
    </Loading>
  );
}

/** Lists (notifications, children): title, then rows. */
export function ParentListSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <Loading>
      <HeaderSkeleton />
      <div aria-hidden className="flex flex-col divide-y divide-ui-border rounded-lg border border-ui-border bg-ui-surface-raised shadow-card">
        {Array.from({ length: rows }, (_, i) => (
          <div key={i} className="flex min-h-ui-row-h items-center justify-between gap-s4 px-s5">
            <Bone className={`h-s4 rounded-md ${i % 3 === 1 ? "w-1/2" : "w-2/3"}`} />
            <Bone className="h-s4 w-s10 shrink-0 rounded-md" />
          </div>
        ))}
      </div>
    </Loading>
  );
}

/** A progress report: the figures row, then charts. */
export function ParentReportSkeleton() {
  return (
    <Loading>
      <HeaderSkeleton />
      <div aria-hidden className="grid grid-cols-2 gap-s4 md:grid-cols-4">
        {Array.from({ length: 4 }, (_, i) => (
          <div key={i} className="flex flex-col gap-s2 rounded-lg border border-ui-border bg-ui-surface-raised p-s5 shadow-card">
            <Bone className="h-s3 w-1/2 rounded-md" />
            <Bone className="h-s7 w-2/3 rounded-md" />
          </div>
        ))}
      </div>
      <div aria-hidden className="mt-s5 grid gap-s5 xl:grid-cols-2">
        {Array.from({ length: 2 }, (_, i) => (
          <div key={i} className="rounded-lg border border-ui-border bg-ui-surface-raised p-s6 shadow-card">
            <Bone className="mb-s5 h-s5 w-1/3 rounded-md" />
            <Bone className="h-ui-chart-h w-full rounded-md" />
          </div>
        ))}
      </div>
    </Loading>
  );
}

/** Anything else (entering a zone for the first time, sign-in steps): a calm centred pulse. */
export function PageLoading() {
  return (
    <Loading className="flex min-h-screen items-center justify-center bg-ui-bg p-s5">
      <div aria-hidden className="flex w-full max-w-ui-form-w flex-col gap-s4">
        <Bone className="h-s8 w-2/3 rounded-md" />
        <Bone className="h-s4 w-full rounded-md" />
        <Bone className="h-s4 w-4/5 rounded-md" />
        <Bone className="mt-s4 min-h-tap-ui w-full rounded-md" />
      </div>
    </Loading>
  );
}
