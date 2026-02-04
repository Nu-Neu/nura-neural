---
doc_type: design
version: 1.0
last_updated: 2026-02-03
owner: Shirin (Media Expert) + Team
status: approved
reference: Nura Trust & Narrative System - UX Design
traceability: Ref HLD v1.1, Ref SRS v2.3, Ref ENG-SPEC v3.1
---

# Design Document: Trust & Narrative Intelligence System
## Nura Platform - User Experience Design v1.0

---

## Document Control

| Version | Date | Contributors | Changes |
|---------|------|--------------|---------|
| 0.9 | Feb 3, 2026 | Shirin (Research) | Initial research findings |
| 1.0 | Feb 3, 2026 | Shirin, Mani, Farzad | Final design approved |

---

## Executive Summary

### The Challenge

کاربران نورا نیاز دارند:
1. **سریع بفهمن** یه خبر چقدر قابل اعتماده (در عرض 3 ثانیه)
2. **بدونن چرا** - دلیل اعتماد یا عدم اعتماد چیه
3. **پیدا کنن** خبرهای مرتبط (narrative discovery)
4. **تشخیص بدن** پروپاگاندا رو از واقعیت

### The Solution

**یه سیستم 3-لایه:**

```
Layer 1: TRUST BADGE (3 seconds)
└─ Badge رنگی با امتیاز → کاربر می‌فهمه "قابل اعتماده یا نه"

Layer 2: TRUST BREAKDOWN (30 seconds)
└─ توضیح چرا؟ → چه دلایلی باعث این امتیاز شده

Layer 3: NARRATIVE VIEW (2-5 minutes)
└─ خبرهای مرتبط → روایت کامل قضیه چیه؟
```

---

## 📚 1. Research Findings (تحقیقات انجام شده)

### 1.1 Stanford UX Study - Credibility Design

**منبع:** University of Washington, "Towards Unified Framework for UX Design of News Credibility Tools" (2021)

**یافته‌های کلیدی:**

> "Users put more emphasis on visual design elements and navigability than actual information when assessing credibility."

**نتیجه‌گیری برای ما:**
- ✅ **Visual design باید قوی باشه** - نه فقط متن
- ✅ **Simple badge system** بهتر از توضیحات طولانی
- ✅ **Color coding** سریع‌ترین روش درک

**سه چالش اصلی که کشف شد:**

| Challenge | User Pain Point | Our Solution |
|-----------|----------------|--------------|
| **Probabilistic outputs** | "چطور بفهمم 72% یعنی چی؟" | امتیاز 15-95 + label واضح (HIGH/MEDIUM/LOW) |
| **Lack of explanation** | "چرا این خبر low trust شده؟" | Breakdown modal با 4 component |
| **No consensus** | "هر tool یه چیز می‌گه!" | Transparent methodology page |

[Ref: RESEARCH-001]

---

### 1.2 ClarifAI Study - Propaganda Detection UX

**منبع:** ACM CHI 2024, "Designing an Automated Propaganda Detection Tool"

**System 1 vs System 2 Thinking:**

```
System 1 (Fast, Intuitive)          System 2 (Slow, Critical)
─────────────────────                ──────────────────────
• Quick scroll                       • Deep reading
• Instant reaction                   • Analysis & reflection
• Visual cues                        • Understanding "why"

UX Goal:                             UX Goal:
→ Badge visible در یک نگاه            → Explanation accessible با یک کلیک
```

**Design Goals کشف شده:**

**DG1: Intuitive Interaction (System 1)**
- Badge has to be **immediately visible**
- Color-coded for instant recognition
- Non-intrusive (doesn't block reading)

**DG2: Critical Analysis (System 2)**
- Explainer available **on-demand** (hover/click)
- Shows **WHY** content flagged
- Educational (user learns propaganda techniques)

**پیاده‌سازی ما:**

| ClarifAI Feature | Nura Equivalent |
|------------------|-----------------|
| Color highlights for propaganda | Color-coded Trust Badge (🟢🟡🔴) |
| Hover for explanation | Click badge → Breakdown Modal |
| Real-time detection | Real-time trust scoring |
| LLM-generated explanations | `explanation` field in API |

[Ref: RESEARCH-002]

---

### 1.3 Badge Design Best Practices

**منبع:** Multiple industry sources (Credly, Certifier, NNG)

**کلیدی‌ترین اصول:**

1. **Simple, bold graphics** - پیچیدگی در سایزهای کوچک خوانا نیست
2. **High contrast** - برای legibility
3. **Avoid gradients** - Flat design بهتره
4. **Scalable** - باید در mobile و desktop خوب باشه
5. **Consistent** - یه badge برای یه سطح اعتماد

**رنگ‌شناسی استاندارد:**

| Color | Meaning | Usage |
|-------|---------|-------|
| 🟢 Green | Positive, Safe, Verified | Trust Score 70-95 |
| 🟡 Yellow/Amber | Caution, Needs verification | Trust Score 40-69 |
| 🔴 Red | Warning, Low trust | Trust Score 15-39 |

[Ref: RESEARCH-003]

---

### 1.4 Narrative Clustering - Real-time News

**منبع:** arXiv 2023, "Real-time News Story Identification"

**چالش:** چطور خبرهای مرتبط رو **بدون جستجوی کاربر** نشون بدیم؟

**روش:** Story identification = clustering articles about same event

**Implementation:**

```
Step 1: Embedding generation (text-embedding-3-small)
Step 2: Vector similarity (pgvector HNSW)
Step 3: Entity overlap (NER: PERSON, ORG, EVENT)
Step 4: Time proximity (14-day window)

Result: narrativeid grouping
```

**UX Implication:**

بجای اینکه کاربر search کنه "Zahedan protest"، ما **automatically** همه خبرهای مرتبط رو زیر یه narrative نشون می‌دیم.

[Ref: RESEARCH-004]

---

## 🎨 2. Design System Components

### 2.1 Trust Badge (Component 1)

**Purpose:** Instant credibility assessment (System 1 thinking)

#### Visual Specifications

```css
.trust-badge {
  display: inline-flex;
  align-items: center;
  padding: 6px 12px;
  border-radius: 9999px; /* Full rounded */
  font-weight: 500;
  font-size: 12px;
  gap: 6px;
  cursor: pointer;
  transition: all 0.2s ease;
}

/* High Trust (70-95) */
.trust-badge--high {
  background: rgba(var(--color-success-rgb), 0.15);
  color: var(--color-success);
  border: 1px solid rgba(var(--color-success-rgb), 0.25);
}

/* Medium Trust (40-69) */
.trust-badge--medium {
  background: rgba(var(--color-warning-rgb), 0.15);
  color: var(--color-warning);
  border: 1px solid rgba(var(--color-warning-rgb), 0.25);
}

/* Low Trust (15-39) */
.trust-badge--low {
  background: rgba(var(--color-error-rgb), 0.15);
  color: var(--color-error);
  border: 1px solid rgba(var(--color-error-rgb), 0.25);
}

.trust-badge:hover {
  transform: scale(1.05);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}
```

#### Badge Variants

**Variant 1: با امتیاز عددی**

```html
<div class="trust-badge trust-badge--high">
  <svg><!-- checkmark icon --></svg>
  <span>قابل اعتماد</span>
  <span class="score">85</span>
</div>
```

**Variant 2: فقط label**

```html
<div class="trust-badge trust-badge--medium">
  <svg><!-- info icon --></svg>
  <span>نیاز به تایید</span>
</div>
```

**Variant 3: با warning**

```html
<div class="trust-badge trust-badge--low">
  <svg><!-- warning icon --></svg>
  <span>غیرقابل اعتماد</span>
  <span class="flag">🚫</span>
</div>
```

#### Icon System

| Trust Level | Icon | SVG |
|-------------|------|-----|
| HIGH | ✓ Checkmark | `<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>` |
| MEDIUM | ⓘ Info | `<circle cx="12" cy="12" r="10"/><path d="M12 16v-4m0-4h.01"/>` |
| LOW | ⚠ Warning | `<path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/>` |

[Ref: DESIGN-001]

---

### 2.2 Trust Breakdown Modal (Component 2)

**Purpose:** Explain "why" the score is X (System 2 thinking)

#### UI Structure

```
┌─────────────────────────────────────────────┐
│  Trust Score Breakdown                   [✕]│
├─────────────────────────────────────────────┤
│                                             │
│  Overall Score: 72  🟡 Medium Trust         │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                             │
│  📊 Score Components:                       │
│                                             │
│  Base (Source)          36 / 45            │
│  ███████████████████████░░░░░░░░░░░        │
│  منبع: HRANA (NGO Watchdog)                │
│                                             │
│  Provenance             20 / 20            │
│  ██████████████████████████████████        │
│  ✓ URL معتبر  ✓ Timestamp  ✓ نویسنده     │
│                                             │
│  Corroboration          14 / 20            │
│  ████████████████████░░░░░░░░░░░░░        │
│  2 منبع مستقل تایید کردن                  │
│                                             │
│  Transparency           11 / 15            │
│  ████████████████████░░░░░░░░░░░░         │
│  ✓ منابع لینک شده  ⚠ روش‌شناسی ناقص     │
│                                             │
│  Modifiers              -9                 │
│  ⚠ منابع ناشناس استفاده شده              │
│                                             │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                             │
│  💡 What does this mean?                    │
│                                             │
│  این خبر از یک منبع معتبر (HRANA) هست ولی  │
│  به دلیل استفاده از منابع ناشناس، امتیاز  │
│  نهایی کاهش پیدا کرده. برای اطمینان کامل،  │
│  بررسی منابع دیگر توصیه می‌شه.             │
│                                             │
│  [Learn More]  [View Sources]              │
│                                             │
└─────────────────────────────────────────────┘
```

#### Interactive Elements

**Progress Bars:**
```css
.breakdown-bar {
  width: 100%;
  height: 8px;
  background: var(--color-secondary);
  border-radius: var(--radius-full);
  overflow: hidden;
}

.breakdown-bar__fill {
  height: 100%;
  background: var(--color-primary);
  transition: width 0.5s ease;
}

/* Animation on modal open */
@keyframes fillBar {
  from { width: 0; }
  to { width: var(--target-width); }
}
```

**Tooltips:**
```html
<span class="tooltip-trigger">
  Provenance
  <svg class="info-icon">...</svg>
  
  <div class="tooltip">
    <strong>Provenance = شفافیت منبع</strong>
    <p>آیا نویسنده مشخصه؟ تاریخ درسته؟ لینک معتبره؟</p>
  </div>
</span>
```

[Ref: DESIGN-002]

---

### 2.3 Narrative Cluster View (Component 3)

**Purpose:** نشون دادن خبرهای مرتبط + تشخیص propaganda

#### Layout

```
┌──────────────────────────────────────────────────────┐
│  📰 Zahedan Protests: Death Toll Rises to 96         │
│  Last Updated: 2 hours ago  •  12 articles           │
├──────────────────────────────────────────────────────┤
│                                                      │
│  🎯 Narrative Summary (AI-generated):                │
│  ────────────────────────────────────                │
│  در 10 ژانویه 2026، اعتراضات گسترده‌ای در زاهدان    │
│  رخ داد. طبق گزارش HRANA، حداقل 96 نفر کشته شدند.   │
│  رژیم این اعداد را تکذیب کرده (3,117 اعلام کرده).  │
│                                                      │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                      │
│  📊 Trust Distribution:                              │
│  ────────────────────────                            │
│  ████████ 67% High Trust (8 articles)                │
│  ███ 25% Medium Trust (3 articles)                   │
│  █ 8% Low Trust (1 article)                          │
│                                                      │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                      │
│  🔍 Articles in this Narrative:                      │
│                                                      │
│  ┌────────────────────────────────────────┐         │
│  │ 🟢 85  HRANA Reports 96 Deaths          │         │
│  │ HRANA • Jan 25, 2026                    │         │
│  │ "Human rights activists documented..."  │         │
│  │ [Read More] [Share]                     │         │
│  └────────────────────────────────────────┘         │
│                                                      │
│  ┌────────────────────────────────────────┐         │
│  │ 🟡 55  NYT: More Than 2,600 Killed      │         │
│  │ New York Times • Jan 16, 2026           │         │
│  │ ⚠ Based on early data (now outdated)   │         │
│  │ [Read More] [Share]                     │         │
│  └────────────────────────────────────────┘         │
│                                                      │
│  ┌────────────────────────────────────────┐         │
│  │ 🔴 18  Regime: 3,117 Killed              │         │
│  │ Tasnim (IRGC Media) • Jan 21, 2026      │         │
│  │ 🚫 Propaganda Alert: 86% underreporting │         │
│  │ [Read More] [Report]                    │         │
│  └────────────────────────────────────────┘         │
│                                                      │
│  [Show All 12 Articles]                              │
│                                                      │
└──────────────────────────────────────────────────────┘
```

#### Interactive Features

**Sorting/Filtering:**
```
[▼ Sort by: Trust Score]  [Filter: ⚪ All  🟢 High  🟡 Medium  🔴 Low]
```

**Timeline View:**
```
Jan 10 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Jan 25

  │                                    │
  ●                                    ●
Protests                          HRANA Report
Start                              (96 deaths)
```

[Ref: DESIGN-003]

---

### 2.4 Propaganda Detection Alert

**Purpose:** Flag propaganda با explainer

#### Visual Design

**Alert Banner:**

```html
<div class="propaganda-alert">
  <div class="alert-header">
    <svg class="icon-warning">...</svg>
    <h4>🚫 Propaganda Alert</h4>
  </div>
  
  <div class="alert-body">
    <p>
      <strong>Why flagged:</strong> 
      این منبع (تسنیم) متعلق به سپاه هست و سابقه 
      85% underreporting داره.
    </p>
    
    <details>
      <summary>📊 Historical Pattern</summary>
      <ul>
        <li>2019 Protests: گفت 225، واقعیت 1,500 (85% کمتر)</li>
        <li>2022 Protests: گفت 83، واقعیت 550 (85% کمتر)</li>
        <li>2026 Protests: گفت 3,117، واقعیت 22,490+ (86% کمتر)</li>
      </ul>
    </details>
    
    <div class="alert-actions">
      <button class="btn btn--secondary">
        View Independent Sources
      </button>
      <a href="/methodology#propaganda">Learn More</a>
    </div>
  </div>
</div>
```

**CSS:**

```css
.propaganda-alert {
  background: rgba(var(--color-error-rgb), 0.08);
  border-left: 4px solid var(--color-error);
  padding: var(--space-16);
  border-radius: var(--radius-md);
  margin: var(--space-16) 0;
}

.propaganda-alert .icon-warning {
  color: var(--color-error);
  width: 24px;
  height: 24px;
}

.alert-header {
  display: flex;
  align-items: center;
  gap: var(--space-8);
  margin-bottom: var(--space-12);
}

details summary {
  cursor: pointer;
  font-weight: var(--font-weight-medium);
  margin-top: var(--space-12);
}

details summary:hover {
  color: var(--color-primary);
}
```

[Ref: DESIGN-004]

---

## 🔄 3. User Flows

### 3.1 Flow A: Quick Assessment (3 seconds)

```
User lands on article
    ↓
Sees Trust Badge (color-coded)
    ↓
Decision:
├─ Green (85) → "Trustworthy, read"
├─ Yellow (55) → "Verify first"
└─ Red (18) → "Propaganda, skip or investigate"
```

**UX Goal:** کاربر در **3 ثانیه** بفهمه باید این خبر رو بخونه یا نه.

---

### 3.2 Flow B: Understanding "Why" (30 seconds)

```
User clicks on Trust Badge
    ↓
Modal opens با Breakdown
    ↓
User sees:
  • Score components (Base, Provenance, Corroboration, Transparency)
  • Warnings/Flags
  • Explanation text
    ↓
Decision:
├─ "Makes sense, trust it"
├─ "Check other sources"
└─ "Learn more about methodology"
```

**UX Goal:** کاربر در **30 ثانیه** بفهمه **چرا** این امتیاز داده شده.

---

### 3.3 Flow C: Narrative Discovery (2-5 minutes)

```
User clicks on Narrative Title
    ↓
Narrative Cluster View opens
    ↓
User sees:
  • AI Summary
  • Trust Distribution
  • 12 related articles sorted by trust
    ↓
User actions:
  ├─ Read high-trust article (HRANA 85)
  ├─ Compare with medium-trust (NYT 55)
  └─ Identify propaganda (Tasnim 18)
    ↓
User understands complete story + propaganda tactics
```

**UX Goal:** کاربر در **2-5 دقیقه** narrative کامل + تشخیص propaganda رو یاد بگیره.

---

## 📱 4. Mobile-First Design

### 4.1 Responsive Breakpoints

```css
/* Mobile First */
.article-card {
  padding: var(--space-12);
}

/* Tablet (768px+) */
@media (min-width: 768px) {
  .article-card {
    padding: var(--space-16);
    display: grid;
    grid-template-columns: 1fr 2fr;
  }
}

/* Desktop (1024px+) */
@media (min-width: 1024px) {
  .article-card {
    padding: var(--space-24);
    grid-template-columns: 1fr 3fr;
  }
}
```

### 4.2 Touch Targets

**Minimum size:** 44x44px (Apple HIG, Material Design)

```css
.trust-badge,
.btn,
.card {
  min-height: 44px;
  min-width: 44px;
}

/* Spacing برای fingers */
.btn-group > * + * {
  margin-left: var(--space-8); /* 8px = safe distance */
}
```

### 4.3 Mobile Modal

**بجای full modal، از Bottom Sheet استفاده می‌کنیم:**

```html
<div class="bottom-sheet">
  <div class="bottom-sheet__handle"></div>
  <div class="bottom-sheet__content">
    <!-- Trust Breakdown content -->
  </div>
</div>
```

```css
.bottom-sheet {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--color-surface);
  border-radius: var(--radius-lg) var(--radius-lg) 0 0;
  max-height: 80vh;
  overflow-y: auto;
  transform: translateY(100%);
  transition: transform 0.3s ease;
}

.bottom-sheet.is-open {
  transform: translateY(0);
}

.bottom-sheet__handle {
  width: 40px;
  height: 4px;
  background: var(--color-border);
  border-radius: var(--radius-full);
  margin: var(--space-12) auto;
}
```

[Ref: DESIGN-005]

---

## ♿ 5. Accessibility (A11Y)

### 5.1 WCAG 2.1 AA Compliance

**Color Contrast:**

| Element | Ratio | WCAG Level |
|---------|-------|------------|
| Body text (16px) | 7:1 | AAA ✓ |
| Badge text (12px) | 4.5:1 | AA ✓ |
| Large text (24px+) | 3:1 | AA ✓ |

**Verification:**
```bash
# Use axe DevTools or WAVE
# Target: 0 violations
```

### 5.2 Keyboard Navigation

**Tab Order:**

```
Article → Trust Badge → Title → Summary → Actions
                ↓
         (Space/Enter opens Modal)
                ↓
   Modal: Close → Components → Sources → Learn More
```

**Focus Indicators:**

```css
*:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

.trust-badge:focus-visible {
  box-shadow: var(--focus-ring);
}
```

### 5.3 Screen Readers

**ARIA Labels:**

```html
<div 
  class="trust-badge trust-badge--high"
  role="button"
  tabindex="0"
  aria-label="Trust score: 85 out of 95. High trust. Click for details."
  aria-expanded="false"
  aria-controls="trust-modal-123"
>
  <span aria-hidden="true">✓</span>
  <span>قابل اعتماد</span>
  <span aria-hidden="true">85</span>
</div>

<div 
  id="trust-modal-123"
  role="dialog"
  aria-labelledby="modal-title"
  aria-describedby="modal-desc"
  aria-modal="true"
  hidden
>
  <h2 id="modal-title">Trust Score Breakdown</h2>
  <p id="modal-desc">Detailed explanation of the 85 trust score</p>
  <!-- ... -->
</div>
```

**Live Regions:**

```html
<!-- برای updates دینامیک -->
<div 
  aria-live="polite" 
  aria-atomic="true"
  class="sr-only"
>
  <!-- JS updates this when narrative count changes -->
  12 articles in this narrative. 8 high trust, 3 medium, 1 low.
</div>
```

### 5.4 Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

[Ref: DESIGN-006]

---

## 🌐 6. Localization (Phase 2 - RTL Support)

**الان:** English-only (LTR)

**بعداً:** Farsi support (RTL)

### 6.1 RTL CSS Strategy

```css
/* Use logical properties بجای left/right */

/* ❌ BAD */
.card {
  margin-left: 16px;
}

/* ✅ GOOD */
.card {
  margin-inline-start: 16px; /* در RTL می‌شه margin-right */
}
```

### 6.2 Mirroring Icons

```css
[dir="rtl"] .arrow-icon {
  transform: scaleX(-1); /* Flip horizontally */
}
```

### 6.3 Font Stack

```css
:root {
  --font-family-en: "FKGroteskNeue", "Inter", sans-serif;
  --font-family-fa: "Vazirmatn", "Tanha", sans-serif;
}

html[lang="en"] {
  font-family: var(--font-family-en);
}

html[lang="fa"] {
  font-family: var(--font-family-fa);
}
```

[Ref: DESIGN-007]

---

## 🚫 7. "No Data" Scenarios

### 7.1 Insufficient Corroboration

**Scenario:** فقط 1 منبع داریم، نمی‌تونیم verify کنیم.

**UI:**

```html
<div class="trust-badge trust-badge--uncertain">
  <svg><!-- question mark icon --></svg>
  <span>قابل تایید نیست</span>
</div>

<!-- در breakdown modal -->
<div class="info-box">
  <h4>⚠️ داده کافی برای تایید نیست</h4>
  <p>
    این خبر فقط توسط 1 منبع گزارش شده. برای اطمینان، 
    منتظر تایید منابع دیگه بمونید.
  </p>
  <button class="btn btn--secondary">
    Notify me when verified
  </button>
</div>
```

**CSS:**

```css
.trust-badge--uncertain {
  background: rgba(var(--color-info-rgb), 0.15);
  color: var(--color-info);
  border: 1px solid rgba(var(--color-info-rgb), 0.25);
}
```

---

### 7.2 Conflicting Sources (Disputed)

**Scenario:** منابع مختلف اعداد متفاوت می‌دن.

**UI:**

```html
<div class="disputed-banner">
  <svg class="icon-alert">...</svg>
  <div>
    <h4>❗ Disputed Claim</h4>
    <p>
      منابع مختلف اعداد متفاوتی گزارش کردن:
      <ul>
        <li>HRANA: 22,490 کشته</li>
        <li>Amnesty: 30,000+ کشته</li>
        <li>Regime: 3,117 کشته</li>
      </ul>
    </p>
    <button class="btn btn--primary">
      Compare All Sources
    </button>
  </div>
</div>
```

---

### 7.3 Breaking News (Too Early)

**Scenario:** خبر تازه منتشر شده، هنوز corroboration نداریم.

**UI:**

```html
<div class="breaking-badge">
  <svg class="icon-lightning">...</svg>
  <span>Breaking News</span>
</div>

<div class="early-warning">
  <h4>⚡ خبر فوری - هنوز تایید نشده</h4>
  <p>
    این خبر 15 دقیقه پیش منتشر شده. 
    امتیاز اعتماد ممکنه تغییر کنه وقتی منابع دیگه تایید کنن.
  </p>
  <p class="timestamp">
    Last checked: 2 minutes ago
  </p>
</div>
```

[Ref: DESIGN-008]

---

## ⚡ 8. Performance Optimization

### 8.1 Lazy Loading

**Images:**

```html
<img 
  src="placeholder.jpg" 
  data-src="actual-image.jpg"
  loading="lazy"
  alt="Description"
/>
```

**Modals:**

```javascript
// Load modal content only when clicked
badge.addEventListener('click', async () => {
  const breakdown = await fetch(`/api/items/${itemId}/trust`);
  renderModal(breakdown);
});
```

### 8.2 Code Splitting

```javascript
// Main bundle (critical)
import { TrustBadge } from './components/TrustBadge';

// Lazy load modal (non-critical)
const TrustModal = lazy(() => import('./components/TrustModal'));
```

### 8.3 Caching Strategy

**API Responses:**

```javascript
// Cache trust scores for 5 minutes
fetch('/api/items/123/trust', {
  headers: {
    'Cache-Control': 'max-age=300'
  }
});
```

**Service Worker:**

```javascript
// Cache static assets (badges, icons)
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open('nura-v1').then((cache) => {
      return cache.addAll([
        '/assets/badge-high.svg',
        '/assets/badge-medium.svg',
        '/assets/badge-low.svg'
      ]);
    })
  );
});
```

[Ref: DESIGN-009]

---

## 📊 9. Analytics & Metrics

### 9.1 User Engagement Tracking

**Events to Track:**

```javascript
// Google Analytics 4 / Mixpanel
analytics.track('trust_badge_clicked', {
  item_id: '123',
  trust_score: 72,
  trust_level: 'MEDIUM',
  source: 'NYT'
});

analytics.track('breakdown_viewed', {
  item_id: '123',
  time_spent: 45, // seconds
  scrolled_to_bottom: true
});

analytics.track('narrative_explored', {
  narrative_id: 'zahedan-protests',
  articles_viewed: 3,
  propaganda_flagged: 1
});
```

### 9.2 Success Metrics (KPIs)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Badge Click Rate** | >25% | clicks / impressions |
| **Modal Completion** | >60% | users who scroll to bottom |
| **Narrative Exploration** | >40% | users who click into cluster |
| **Share Rate** | >15% | shares / unique viewers |
| **Return Rate** | >50% | users who return within 7 days |

### 9.3 A/B Testing

**Hypothesis 1:** Badge با عدد (85) vs بدون عدد

```
Group A: "✓ قابل اعتماد 85"
Group B: "✓ قابل اعتماد"

Measure: Click-through rate
```

**Hypothesis 2:** Modal position (Center vs Bottom Sheet)

```
Group A: Center modal (desktop style)
Group B: Bottom sheet (mobile native)

Measure: Completion rate
```

[Ref: DESIGN-010]

---

## 🎓 10. User Education

### 10.1 Onboarding Flow

**First Visit:**

```
┌─────────────────────────────────────┐
│  Welcome to Nura! 👋                 │
├─────────────────────────────────────┤
│                                     │
│  ما به شما کمک می‌کنیم خبرهای      │
│  قابل اعتماد رو از propaganda       │
│  تشخیص بدید.                         │
│                                     │
│  [Next]                             │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Trust Badges 🎯                     │
├─────────────────────────────────────┤
│                                     │
│  🟢 85  = قابل اعتماد               │
│  🟡 55  = نیاز به تایید             │
│  🔴 18  = غیرقابل اعتماد            │
│                                     │
│  کلیک کنید برای جزئیات بیشتر →     │
│                                     │
│  [Next]                             │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Ready to Start! 🚀                  │
├─────────────────────────────────────┤
│                                     │
│  حالا می‌تونید اخبار رو با اعتماد   │
│  بخونید.                            │
│                                     │
│  [✓ Don't show again]  [Get Started]│
└─────────────────────────────────────┘
```

### 10.2 Methodology Page

**URL:** `/methodology`

**Sections:**

1. **Trust Scoring Formula**
   - توضیح 4 component (Base, Provenance, Corroboration, Transparency)
   - مثال‌های واقعی

2. **Source Classification**
   - 6-tier taxonomy (Regime → Wire)
   - چرا HRANA = 90 ولی Tasnim = 18?

3. **Propaganda Detection**
   - ProxyScore چطور کار می‌کنه
   - Historical patterns

4. **Narrative Clustering**
   - چطور خبرهای مرتبط رو پیدا می‌کنیم
   - Entity overlap + vector similarity

5. **Transparency**
   - همه تصمیمات ما documented هستن
   - Source Bible قابل دسترسه

[Ref: DESIGN-011]

---

## 🛠️ 11. Implementation Roadmap

### Week 1-2: Core Components

**Deliverables:**
- ✅ Trust Badge component (3 variants)
- ✅ Breakdown Modal (desktop + mobile)
- ✅ API integration (`/api/items/{id}/trust`)

**Owner:** Farzad (UI), Mani (UX review)

---

### Week 3: Narrative View

**Deliverables:**
- ✅ Narrative Cluster layout
- ✅ Timeline view
- ✅ Propaganda alert banner

**Owner:** Farzad

---

### Week 4: Polish & Testing

**Deliverables:**
- ✅ A11Y audit (WCAG AA)
- ✅ Mobile optimization
- ✅ Performance testing (Lighthouse >90)
- ✅ Onboarding flow

**Owner:** Mani (lead), Farzad (implementation)

---

### Phase 2 (Month 2+):

- RTL support (Farsi UI)
- Advanced filters
- User accounts + personalization
- Notification system ("Notify when verified")

[Ref: DESIGN-012]

---

## 🧪 12. Testing Checklist

### 12.1 Functional Testing

- [ ] Trust Badge renders correctly for all levels (HIGH/MEDIUM/LOW)
- [ ] Modal opens/closes با keyboard (Space, Enter, Esc)
- [ ] Breakdown bars animate smoothly
- [ ] Propaganda alert shows for Regime sources
- [ ] Narrative cluster sorts by trust score
- [ ] "No data" states display correctly

### 12.2 Cross-Browser Testing

- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)
- [ ] Mobile Safari (iOS 15+)
- [ ] Chrome Mobile (Android 12+)

### 12.3 Accessibility Testing

- [ ] Keyboard navigation (tab order correct)
- [ ] Screen reader (NVDA/JAWS/VoiceOver)
- [ ] Color contrast (4.5:1 minimum)
- [ ] Focus indicators visible
- [ ] ARIA labels present

### 12.4 Performance Testing

- [ ] Lighthouse score >90
- [ ] First Contentful Paint <1.5s
- [ ] Time to Interactive <3s
- [ ] Modal load time <200ms

[Ref: DESIGN-013]

---

## 📝 13. Design Tokens

```css
:root {
  /* Trust Colors */
  --trust-high: var(--color-success);      /* 🟢 Green */
  --trust-medium: var(--color-warning);    /* 🟡 Amber */
  --trust-low: var(--color-error);         /* 🔴 Red */
  --trust-uncertain: var(--color-info);    /* 🔵 Blue */
  
  /* Badge Sizes */
  --badge-sm: 24px;   /* Compact list */
  --badge-md: 32px;   /* Card default */
  --badge-lg: 44px;   /* Featured */
  
  /* Modal */
  --modal-max-width: 600px;
  --modal-padding: var(--space-24);
  --modal-backdrop: rgba(0, 0, 0, 0.5);
  
  /* Animation */
  --duration-badge: 200ms;
  --duration-modal: 300ms;
  --ease-bounce: cubic-bezier(0.68, -0.55, 0.265, 1.55);
}
```

[Ref: DESIGN-014]

---

## 🎯 14. Success Criteria

### MVP Launch (Week 4):

- ✅ **Badge visible در <3s** load time
- ✅ **Modal interactive** با keyboard + mouse
- ✅ **Narrative view functional** با sorting
- ✅ **0 critical A11Y violations** (axe audit)
- ✅ **Methodology page live** (/methodology)

### Month 1 Post-Launch:

- ✅ **>25% badge click rate**
- ✅ **>60% modal completion rate**
- ✅ **>40% narrative exploration**
- ✅ **<2% error rate** (API/UI bugs)

### Month 3 Goals:

- ✅ **50+ DAU** (Daily Active Users)
- ✅ **5min avg session duration**
- ✅ **15% share rate**
- ✅ **Positive user feedback** (survey: 4+/5)

[Ref: DESIGN-015]

---

## 📚 15. References

### Academic Research

[RESEARCH-001] Stomber, J. et al. (2021). "Towards a Unified Framework for the UX Design of News Credibility Tools." *ACM Conference on Human Factors in Computing Systems (CHI).*

[RESEARCH-002] Zavolokina, L. et al. (2024). "Designing an Automated Propaganda Detection Tool: ClarifAI." *ACM Conference on Human Factors in Computing Systems (CHI).* DOI: 10.1145/3613904.3642805

[RESEARCH-003] Credly. (2024). "Badge Visuals and Graphics: Best Practices and Technical Requirements."

[RESEARCH-004] Stomber, J. (2023). "Real-time News Story Identification via Clustering." *arXiv:2508.08272v1.*

### Industry Standards

- Nielsen Norman Group (NNG) - "Indicators, Validations, and Notifications" (2024)
- WCAG 2.1 Level AA Guidelines
- Apple Human Interface Guidelines (HIG)
- Material Design 3 (Google)

### Internal Documents

- [HLD v1.1] High-Level Design: Nura Platform Architecture
- [SRS v2.3] Software Requirements Specification
- [ENG-SPEC v3.1] Engineering Specification: Trust Scoring & Narrative Intelligence
- [UX Strategy v1.0] User Experience Strategy & Personas

[Ref: DESIGN-016]

---

## 16. Appendices

### Appendix A: Design Assets

**Figma Files:**
- `nura-trust-badge-variants.fig`
- `nura-breakdown-modal.fig`
- `nura-narrative-cluster.fig`

**Icon Library:**
- `/assets/icons/trust-high.svg`
- `/assets/icons/trust-medium.svg`
- `/assets/icons/trust-low.svg`
- `/assets/icons/propaganda-alert.svg`

**Typography:**
- FKGroteskNeue (Latin)
- Vazirmatn (Persian - Phase 2)

---

### Appendix B: Component Library

**React Components (Framer):**

```javascript
// Trust Badge
<TrustBadge 
  score={85}
  level="HIGH"
  onClick={() => openModal()}
  aria-label="Trust score 85. Click for details."
/>

// Breakdown Modal
<TrustModal
  isOpen={modalOpen}
  onClose={() => setModalOpen(false)}
  data={trustBreakdown}
/>

// Narrative Cluster
<NarrativeCluster
  narrativeId="zahedan-protests"
  articles={relatedArticles}
  sortBy="trustScore"
/>

// Propaganda Alert
<PropagandaAlert
  source={sourceProfile}
  historicalData={underreportingPattern}
/>
```

---

### Appendix C: Glossary

| Term | English | Farsi |
|------|---------|-------|
| Trust Score | Trust Score | امتیاز اعتماد |
| High Trust | High Trust | قابل اعتماد |
| Medium Trust | Medium Trust | نیاز به تایید |
| Low Trust | Low Trust | غیرقابل اعتماد |
| Propaganda | Propaganda | پروپاگاندا |
| Narrative | Narrative | روایت |
| Corroboration | Corroboration | تایید مستقل |
| Source | Source | منبع |
| Breakdown | Breakdown | جزئیات امتیاز |

---

## Sign-off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Media Expert (Research) | Shirin | Approved | Feb 3, 2026 |
| UX Lead | Mani | Approved | Feb 3, 2026 |
| UI Designer | Farzad | Approved | Feb 3, 2026 |
| Product Owner | [Your Name] | Awaiting | - |

**Document Status:** ✅ **Approved for Implementation**

---

## Next Steps

**Immediate Actions (Next 24h):**

1. **Farzad:** Start Trust Badge component (3 variants)
2. **Mani:** Create clickable prototype in Figma
3. **Amir:** Review API response schema alignment

**Week 1 Kickoff:**

- Daily standup: 9 AM NZDT
- Design review: Wednesday 2 PM NZDT
- User testing: Friday with 2-3 early users

---

**Last Updated:** Tuesday, February 3, 2026, 1:46 PM NZDT  
**Version:** 1.0 Final  
**File:** `docs/design-trust-narrative-system-v1.0.md`

---

**این مستند source of truth برای طراحی UX سیستم Trust & Narrative هست. همه تصمیمات UI/UX به بخش‌های مشخص شده با [Ref: DESIGN-XXX] برمی‌گرده.**

**سوالات؟ Escalate به Mani (UX Lead) یا Product Owner.**

---

