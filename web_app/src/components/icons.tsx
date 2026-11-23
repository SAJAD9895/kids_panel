// Simple line icons drawn for this app (no icon library, no brand art). currentColor throughout.
type P = { className?: string; title?: string };
const S = ({ children, className = "size-icon-md", title }: P & { children: React.ReactNode }) => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" className={className} aria-hidden={title ? undefined : true} role={title ? "img" : undefined}>
    {title && <title>{title}</title>}{children}
  </svg>
);
export const HomeIcon = (p: P) => <S {...p}><path d="M3 11l9-7 9 7" /><path d="M5 10v10h14V10" /><path d="M10 20v-6h4v6" /></S>;
export const LearnIcon = (p: P) => <S {...p}><path d="M4 5h6a2 2 0 012 2v13a2 2 0 00-2-2H4z" /><path d="M20 5h-6a2 2 0 00-2 2v13a2 2 0 012-2h6z" /></S>;
export const GamesIcon = (p: P) => <S {...p}><path d="M9 3h6v4a2 2 0 104 0h2v6h-4a2 2 0 100 4h4v4H9v-4a2 2 0 10-4 0H3v-6h4a2 2 0 100-4H3V3h6" /></S>;
export const WatchIcon = (p: P) => <S {...p}><rect x="3" y="5" width="18" height="14" rx="3" /><path d="M10 9l5 3-5 3z" /></S>;
export const ListenIcon = (p: P) => <S {...p}><path d="M9 18V6l11-2v12" /><circle cx="6" cy="18" r="3" /><circle cx="17" cy="16" r="3" /></S>;
export const MeIcon = (p: P) => <S {...p}><circle cx="12" cy="8" r="4" /><path d="M4 21c1-4 4-6 8-6s7 2 8 6" /></S>;
export const StarIcon = (p: P) => <S {...p}><path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z" fill="currentColor" /></S>;
export const LockIcon = (p: P) => <S {...p}><rect x="5" y="11" width="14" height="10" rx="2" /><path d="M8 11V7a4 4 0 018 0v4" /></S>;
export const BackIcon = (p: P) => <S {...p}><path d="M15 5l-7 7 7 7" /></S>;
export const PlayIcon = (p: P) => <S {...p}><path d="M7 4l13 8-13 8z" fill="currentColor" /></S>;
export const PauseIcon = (p: P) => <S {...p}><path d="M7 4h3v16H7zM14 4h3v16h-3z" fill="currentColor" /></S>;
export const CheckIcon = (p: P) => <S {...p}><path d="M4 12l5 5L20 6" /></S>;
export const SpeakerIcon = (p: P) => <S {...p}><path d="M4 9h4l5-4v14l-5-4H4z" /><path d="M17 9a4 4 0 010 6" /></S>;
export const NextIcon = (p: P) => <S {...p}><path d="M9 5l7 7-7 7" /></S>;
export const ParentIcon = (p: P) => <S {...p}><circle cx="9" cy="7" r="3" /><circle cx="17" cy="9" r="2" /><path d="M3 20c.6-3.5 3-5.5 6-5.5s5.4 2 6 5.5" /><path d="M15 20c.3-2.2 1.5-3.6 3-3.9" /></S>;
export const HintIcon = (p: P) => <S {...p}><path d="M9 18h6M10 21h4" /><path d="M12 3a6 6 0 00-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0012 3z" /></S>;
