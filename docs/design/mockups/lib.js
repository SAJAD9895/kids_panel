/* Mockup helpers: original characters (SVG), avatars, icons, and single-frame mode for screenshots.
   Characters are ours: Pip (seedling), Bolt (robot), Nova (star). No resemblance to any existing brand. */
const C = (n) => `var(--color-${n})`;

function eyes(cx, cy, gap, r, mood) {
  const L = cx - gap, R = cx + gap;
  if (mood === 'happy') return `<path d="M${L-r} ${cy} q${r} ${-r*1.4} ${r*2} 0 M${R-r} ${cy} q${r} ${-r*1.4} ${r*2} 0" stroke="${C('kids-ink')}" stroke-width="${r*0.55}" fill="none" stroke-linecap="round"/>`;
  return `<circle cx="${L}" cy="${cy}" r="${r}" fill="${C('kids-ink')}"/><circle cx="${R}" cy="${cy}" r="${r}" fill="${C('kids-ink')}"/>
          <circle cx="${L+r*0.35}" cy="${cy-r*0.35}" r="${r*0.35}" fill="#fff"/><circle cx="${R+r*0.35}" cy="${cy-r*0.35}" r="${r*0.35}" fill="#fff"/>`;
}
const smile = (cx, cy, w) => `<path d="M${cx-w} ${cy} q${w} ${w*0.9} ${w*2} 0" stroke="${C('kids-ink')}" stroke-width="${w*0.28}" fill="none" stroke-linecap="round"/>`;
const cheeks = (cx, cy, gap) => `<circle cx="${cx-gap}" cy="${cy}" r="6" fill="${C('kids-play-fill')}" opacity=".45"/><circle cx="${cx+gap}" cy="${cy}" r="6" fill="${C('kids-play-fill')}" opacity=".45"/>`;

const CHARS = {
  pip: (mood) => `<svg viewBox="0 0 120 130" aria-hidden="true">
     <path d="M60 30 C40 6 18 14 22 30 C34 34 50 34 60 30Z" fill="${C('kids-success')}"/>
     <path d="M60 30 C80 4 104 12 98 28 C86 34 70 34 60 30Z" fill="${C('kids-me-fill')}"/>
     <rect x="57" y="22" width="6" height="16" rx="3" fill="${C('kids-success')}"/>
     <ellipse cx="60" cy="82" rx="46" ry="44" fill="${C('kids-me-fill')}"/>
     <ellipse cx="60" cy="96" rx="30" ry="22" fill="${C('kids-me-soft')}"/>
     ${eyes(60,74,15,7,mood)}${smile(60,90,9)}${cheeks(60,86,30)}</svg>`,
  bolt: (mood) => `<svg viewBox="0 0 120 130" aria-hidden="true">
     <line x1="60" y1="8" x2="60" y2="28" stroke="${C('kids-ink')}" stroke-width="5" stroke-linecap="round"/>
     <circle cx="60" cy="10" r="8" fill="${C('kids-play-fill')}"/>
     <rect x="14" y="28" width="92" height="84" rx="30" fill="${C('kids-learn-fill')}"/>
     <rect x="26" y="42" width="68" height="46" rx="18" fill="${C('kids-learn-soft')}"/>
     ${eyes(60,62,14,6,mood)}${smile(60,74,8)}
     <rect x="4" y="60" width="12" height="26" rx="6" fill="${C('kids-learn-ink')}"/><rect x="104" y="60" width="12" height="26" rx="6" fill="${C('kids-learn-ink')}"/></svg>`,
  nova: (mood) => `<svg viewBox="0 0 120 130" aria-hidden="true">
     <path d="M60 8 L74 44 L112 46 L82 70 L93 108 L60 86 L27 108 L38 70 L8 46 L46 44 Z" fill="${C('kids-listen-fill')}" stroke="${C('kids-listen-fill')}" stroke-width="10" stroke-linejoin="round"/>
     ${eyes(60,58,12,6,mood)}${smile(60,72,7)}${cheeks(60,68,24)}</svg>`,
};
function char(name, size = 120, mood = 'normal') {
  return `<span class="char" style="display:inline-block;width:${size}px;height:${size*130/120}px">${CHARS[name](mood)}</span>`;
}

/* Buddy avatars: generated blob creatures (body colour x shape x top feature) */
const BODY = ['play','learn','watch','listen','me','play','learn','watch','listen','me','learn','play'];
const TOP = ['ears','antenna','leaf','horns','tuft','ears','leaf','antenna','tuft','horns','ears','leaf'];
function buddy(i, size = 72) {
  const s = BODY[i % 12], t = TOP[i % 12], fill = C(`kids-${s}-fill`), soft = C(`kids-${s}-soft`);
  const tops = {
    ears: `<circle cx="28" cy="26" r="12" fill="${fill}"/><circle cx="72" cy="26" r="12" fill="${fill}"/>`,
    antenna: `<line x1="50" y1="6" x2="50" y2="22" stroke="${C('kids-ink')}" stroke-width="4"/><circle cx="50" cy="7" r="6" fill="${C('kids-star')}"/>`,
    leaf: `<path d="M50 20 C38 2 24 8 28 18 C36 22 44 22 50 20Z" fill="${C('kids-success')}"/>`,
    horns: `<path d="M28 26 L22 6 L38 20Z M72 26 L78 6 L62 20Z" fill="${C('kids-ink')}"/>`,
    tuft: `<path d="M38 20 q6 -16 12 0 q6 -16 12 0" stroke="${fill}" stroke-width="8" fill="none" stroke-linecap="round"/>`,
  };
  return `<svg viewBox="0 0 100 100" width="${size}" height="${size}" aria-hidden="true">${tops[t]}
    <rect x="12" y="20" width="76" height="74" rx="${i%3===0?38:28}" fill="${fill}"/>
    <ellipse cx="50" cy="72" rx="24" ry="16" fill="${soft}"/>${eyes(50,52,12,6,i%4===1?'happy':'normal')}${smile(50,66,7)}</svg>`;
}

/* small helpers used by the pages */
const ic = (n, extra = '') => `<i data-lucide="${n}" ${extra}></i>`;
const stars = (n) => `<span class="nstar">${Array.from({length:n},()=>ic('star')).join('')}</span>`;

function render() {
  document.querySelectorAll('[data-char]').forEach(el => { el.innerHTML = char(el.dataset.char, +el.dataset.size || 120, el.dataset.mood); });
  document.querySelectorAll('[data-buddy]').forEach(el => { el.innerHTML = buddy(+el.dataset.buddy, +el.dataset.size || 72); });
  if (window.lucide) lucide.createIcons();
  // single-frame mode for screenshots: page.html#K07
  const id = location.hash.slice(1);
  if (id) {
    document.body.classList.add('solo');
    const f = document.getElementById(id);
    if (f) f.closest('.shot').classList.add('on');
  }
}
window.addEventListener('DOMContentLoaded', render);
