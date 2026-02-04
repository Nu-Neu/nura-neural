
# Requirements Document


---
doc_type: requirements
version: 2.6
last_updated: 2026-02-04
owner: تیم نورا نِرُال
status: approved
language: fa
english_version: docs/en/02-requirements.md
traceability: [Ref: 01-discovery-and-planning.md]
adr_compliance: [ADR-0001, ADR-0002, ADR-0003, ADR-0004]
***

# مشخصات الزامات نرم‌افزار (SRS) - پلتفرم نورا

## کنترل نسخه

| فیلد | مقدار |
| :-- | :-- |
| **نسخه** | 2.6 (نهایی - همگام‌سازی‌شده با ADRها) |
| **تاریخ** | ۴ فوریه ۲۰۲۶ |
| **مالک** | تیم نورا نِرُال |
| **وضعیت** | تأیید شده برای پیاده‌سازی |
| **زبان** | فارسی (FA) |
| **تطابق با ADR** | ADR-0001 (SQL Migrations), ADR-0002 (Cost Optimization), ADR-0003 (Batch Processing), ADR-0004 (Translation Strategy) |

### تاریخچه تغییرات

| نسخه | تاریخ | مشارکت‌کنندگان | تغییرات |
| :-- | :-- | :-- | :-- |
| 1.0 | ۴ فوریه ۲۰۲۶ | تیم محصول | نسخه اولیه با User Stories کلی |
| 2.4 | ۳ فوریه ۲۰۲۶ | محصول، UX، مهندسی | نسخه انگلیسی کامل SRS با تمام الزامات تفصیلی |
| 2.5 | ۴ فوریه ۲۰۲۶ | تیم نورا | نسخه فارسی یکپارچه: ادغام تمام الزامات عملکردی، فرمول‌ها، معیارها و سناریوهای تست |
| **2.6** | **۴ فوریه ۲۰۲۶** | **تیم نورا** | **همگام‌سازی با ADRهای مصوب: تغییر به GPT-5-nano، Dual Storage، Batch Processing، Pre-filtering، حذف ارجاعات خارجی** |


***

## ۱. الزامات کارکردی (Functional Requirements)

### ۱.۱ ماژول: لایه دریافت داده (Data Ingestion Layer)

#### REQ-ING-001: دریافت خودکار از فیدهای RSS

**داستان کاربر:**
به‌عنوان **مدیر سیستم**، می‌خواهم پلتفرم به‌طور خودکار اخبار را از فیدهای RSS پیکربندی‌شده هر ۱۵ دقیقه یک‌بار دریافت کند تا پایگاه‌داده همیشه آخرین مقالات را داشته باشد.

**معیارهای پذیرش:**

۱. Workflow در n8n هر ۱۵ دقیقه اجرا شود (cron: `*/15`)
۲. Workflow لیست ۵۰۰ منبع RSS از جدول `source_profiles` پردازش کند
3. هر آیتم دریافت‌شده با استفاده از `url_hash` (SHA-256) برای تکراری بودن بررسی شود
4. اگر تکراری بود، آیتم Skip شود و با دلیل `DUPLICATE_URL` لاگ شود
5. عکس HTML خام در Azure Blob Storage (Hot Tier) ذخیره شود با مسیر: `raw/{source_id}/{date}/{url_hash}.html`
6. متادیتا (عنوان، متن، نویسنده، تاریخ انتشار) با **GPT-5-nano** استخراج شود
7. اگر استخراج با GPT-5-nano شکست خورد یا کیفیت پایین بود، به GPT-4o-mini برای پردازش مجدد ارجاع شود
8. زبان محتوا با استفاده از `langdetect` تشخیص داده شود و در فیلد `language_detected` ذخیره شود
9. اگر محتوا به زبان فارسی یا عربی باشد، با GPT-5-nano به انگلیسی ترجمه شود و در فیلدهای `title_en`, `body_en` ذخیره شود
10. داده استخراج‌شده در جدول `items` با وضعیت `PENDING_ANALYSIS` درج شود

**الزامات عملکردی:**

- زمان پردازش هر آیتم: ≤۵ ثانیه (P95)
- اندازه دسته: ۵۰ آیتم در هر اجرا
- نرخ خطا: <۲٪ (شکست‌های شبکه استثنا)

**تطابق با ADR:**

- ADR-0002: استفاده از GPT-5-nano برای کاهش هزینه، fallback به GPT-4o-mini
- ADR-0004: ذخیره دوگانه (original + translation) برای تأیید کاربر

***

#### REQ-ING-002: دریافت داده از Twitter/X

**داستان کاربر:**
به‌عنوان **مدیر سیستم**، می‌خواهم پلتفرم اکانت‌ها و هشتگ‌های خاص توییتر را رصد کند تا ژورنالیسم شهروندی و به‌روزرسانی‌های لحظه‌ای ثبت شوند.

**معیارهای پذیرش:**

1. یکپارچه‌سازی Twitter API v2 از طریق n8n (احراز هویت OAuth 2.0)
2. رصد ۲۰۰ اکانت از Source Bible (روزنامه‌نگاران شهروندی تأییدشده، فعالان)
3. رصد هشتگ‌ها: `#IranProtests`, `#MahsaAmini`, `#OpIran` (قابل تنظیم)
4. فاصله زمانی polling: هر ۵ دقیقه برای اکانت‌های اولویت‌دار، ۱۵ دقیقه برای بقیه
5. توییت‌ها با استفاده از `tweet_id` (کلید اصلی) dedup شوند
6. پیوست‌های رسانه‌ای (تصاویر/ویدیوها) به Azure Blob Storage دانلود شوند
7. متادیتای توییت استخراج شود: `author_handle`, `verified_status`, `retweet_count`, `like_count`, `timestamp`
8. اگر توییت به فارسی یا عربی باشد، با GPT-5-nano ترجمه شود

**موارد خاص (Edge Cases):**

- **توییت‌های حذف‌شده:** علامت بزن به `DELETED`، از DB پاک نکن
- **اکانت‌های معلق‌شده:** هشدار ثبت کن، رصد را برای ۲۴ ساعت غیرفعال کن

***

#### REQ-ING-003: حذف تکراری‌ها (Deduplication)

**داستان کاربر:**
به‌عنوان **مهندس داده**، می‌خواهم سیستم مقالات تکراری را تشخیص داده و فیلتر کند تا هزینه‌های ذخیره‌سازی به حداقل برسد و کیفیت تحلیل حفظ شود.

**معیارهای پذیرش:**

1. **Dedup بر اساس URL:** محاسبه SHA-256 hash از URL استاندارد (حذف UTM params، trailing slash)
2. **Dedup بر اساس محتوا:** محاسبه SimHash از `title + body_text` (امضای ۱۰۲۴ بیتی)
3. اگر شباهت SimHash ≥۹۵٪ با آیتم موجود در ۲۴ ساعت گذشته، علامت بزن `REPRINT`
4. Reprintها به آیتم اصلی لینک شوند از طریق `original_item_id` (FK به `items.id`)
5. Reprintها Trust Scoring را trigger نکنند (امتیاز را از اصلی به ارث ببرند)
6. منطق Dedup **قبل از** استخراج GPT-5-nano اجرا شود تا هزینه API صرفه‌جویی شود

**عملکرد:**

- بررسی dedup: ≤۵۰ms برای هر آیتم (با استفاده از `url_hash` و `content_hash` ایندکس‌شده)

***

#### REQ-ING-004: فیلتر زبانی

**داستان کاربر:**
به‌عنوان **کنترل‌کننده هزینه**، می‌خواهم سیستم مقالات غیر از زبان‌های پشتیبانی‌شده را دور بریزد تا هزینه‌های API برای محتوای غیرمرتبط هدر نرود.

**معیارهای پذیرش:**

1. تشخیص زبان با استفاده از کتابخانه `langdetect` (Python)
2. زبان‌های پشتیبانی‌شده: انگلیسی (EN)، فارسی (FA)، عربی (AR)
3. آیتم‌هایی که در زبان‌های پشتیبانی‌شده نیستند با وضعیت `LANGUAGE_MISMATCH` علامت بزن
4. آیتم‌های دورریخته‌شده با کد زبان تشخیص‌داده‌شده (ISO 639-1) لاگ شوند
5. آیتم‌های دورریخته‌شده در جدول `items` ذخیره **نشوند** (فیلتر قبل از درج)

**استثنا:**

- اگر `source_class = INTL_WIRE` (Reuters، AP، AFP)، همه زبان‌ها را برای گسترش آینده مجاز کن

***

#### REQ-ING-005: فیلتر پیش‌پردازش محتوا (Pre-filtering)

**داستان کاربر:**
به‌عنوان **کنترل‌کننده هزینه**، می‌خواهم محتوای نامرتبط (ورزشی، سرگرمی، تبلیغات) قبل از ورود به pipeline پردازش فیلتر شود تا هزینه‌های ترجمه و تحلیل صرفه‌جویی شود.

**معیارهای پذیرش:**

1. **پیکربندی Miniflux Rule Engine:**
    - فیلترها در سطح RSS feed اعمال شوند (zero-cost، قبل از ورود به n8n)
    - استفاده از keyword blocklist برای شناسایی محتوای نامرتبط
2. **دسته‌های فیلترشده:**
    - ورزشی: `فوتبال، لیگ، بازیکن، مسابقه، گل`
    - سرگرمی: `بازیگر، فیلم، سریال، موسیقی، کنسرت`
    - تبلیغات: `تخفیف، خرید، فروش، محصول`
    - موضوعات غیرسیاسی: `آشپزی، مد، زیبایی`
3. **لاگ‌گذاری:**
    - تمام آیتم‌های فیلترشده در جدول `filtered_items_log` ذخیره شوند
    - فیلدها: `url`, `title`, `source_id`, `filter_reason`, `matched_keywords`, `timestamp`
4. **تنظیم دوره‌ای (Periodic Tuning):**
    - بررسی هفتگی لاگ‌ها برای شناسایی false positives/negatives
    - به‌روزرسانی blocklist بر اساس بازخورد

**عملکرد:**

- فیلتر قبل از ورود به سیستم (zero API cost)
- هدف: کاهش ۳۰-۴۰٪ حجم محتوای دریافتی

**تطابق با ADR:**

- ADR-0004: "Zero-Cost Pre-Filtering" برای کاهش هزینه ترجمه

***

### ۱.۲ ماژول: لایه استدلال هوش مصنوعی (AI Reasoning Layer)

#### REQ-AI-001: محاسبه امتیاز اعتماد (Trust Score Calculation)

**داستان کاربر:**
به‌عنوان **تحلیلگر**، می‌خواهم هر آیتم خبری یک Trust Score (۱۵-۹۵) داشته باشد تا بدون خواندن مقاله کامل بتوانم سریعاً اعتبار را ارزیابی کنم.

**معیارهای پذیرش:**

1. **فرمول محاسبه امتیاز اعتماد (قطعی - Deterministic):**

```text
امتیاز نهایی = پایه + منشأ + تأیید_متقابل + شفافیت + تعدیل‌کننده‌ها

محدوده نهایی: CLAMP(امتیاز_محاسبه‌شده، 15، 95)
```

2. **اجزای فرمول:**


| جزء | محدوده امتیاز | توضیح |
| :-- | :-- | :-- |
| **پایه (Base)** | ۰-۴۵ | بر اساس `source_profiles.base_score`، طبقه‌بندی رسانه (NGO: 40-45، Wire: 35-40، Regime: 15-25) |
| **منشأ (Provenance)** | ۰-۲۰ | اعتبار URL (+5)، timestamp معتبر (+3)، نام نویسنده (+4)، dateline (+3)، رسانه پیوست‌شده (+5) |
| **تأیید متقابل (Corroboration)** | ۰-۲۰ | ≥3 منبع مستقل (+20)، 2 منبع (+15)، 1 منبع (+10)، هیچ (+0) |
| **شفافیت (Transparency)** | ۰-۱۵ | افشای سردبیری (+7)، سیاست اصلاح خطا (+5)، لینک اسناد اولیه (+3) |
| **تعدیل‌کننده‌ها (Modifiers)** | -۱۵ تا +۱۰ | پرچم‌های قرمز: منبع ناشناس (-5)، عدم تأیید ادعاهای عددی (-10)؛ پرچم‌های سبز: اسناد رسمی (+5)، عکس‌های تأییدشده (+5) |

3. **الگوریتم تأیید متقابل (Corroboration):**
    - جستجوی برداری (vector search) در پایگاه داده با استفاده از pgvector
    - شباهت کسینوسی ≥۰.۸۰ با embeddings آیتم‌های موجود
    - فقط منابعی که `source_class` متفاوت دارند (مثلاً NGO نمی‌تواند NGO دیگر را تأیید کند)
    - منابع پروکسی رژیم (ProxyScore ≥70) نمی‌توانند منابع رژیم دیگر را تأیید کنند
4. امتیاز نهایی بین ۱۵ و ۹۵ محدود شود (بدون استثنا)
5. **تأخیر محاسبه (دو حالت):**
    - **Real-time (آیتم‌های جدید):** ≤۶۰ ثانیه از زمان دریافت
    - **Batch (historical/bulk analysis):** ≤۲۴ ساعت، استفاده از الگوی Store-and-Forward
6. **الگوی Batch Processing:**
    - **Accumulate:** آیتم‌های pending در جدول `trust_score_queue` با وضعیت `PENDING`
    - **Dispatch:** n8n هر ساعت batch job را trigger می‌کند، فایل `.jsonl` به OpenAI Batch API ارسال می‌شود
    - **Reconcile:** poller هر ۱۵ دقیقه وضعیت batch را چک می‌کند، نتایج را در `trust_signals` می‌نویسد
7. نتیجه در جدول `trust_signals` ذخیره شود با فیلدهای:
    - `final_score` (INT)
    - `trust_level` (ENUM: HIGH، MEDIUM، LOW)
    - `breakdown_json` (JSONB با امتیازهای تفکیک‌شده هر جزء)
    - `explanation` (TEXT، خلاصه قابل‌فهم برای انسان به زبان ساده)
    - `processing_mode` (ENUM: REALTIME، BATCH)

**تبدیل امتیاز به سطح اعتماد:**


| محدوده امتیاز | سطح اعتماد (trust_level) | رنگ نشان UI |
| :-- | :-- | :-- |
| ۷۰-۹۵ | بالا (HIGH) | سبز |
| ۴۰-۶۹ | متوسط (MEDIUM) | زرد/عنبری |
| ۱۵-۳۹ | پایین (LOW) | قرمز |

**مثال محاسبه:**

```text
آیتم: گزارش HRANA درباره اعتراضات زاهدان
- پایه: 40 (NGO_WATCHDOG)
- منشأ: 18 (URL معتبر +5، نویسنده +4، dateline +3، عکس +5، تاریخ +1)
- تأیید متقابل: 15 (2 منبع مستقل: BBC Persian + Iran Human Rights)
- شفافیت: 12 (افشای سردبیری +7، سیاست اصلاح +5)
- تعدیل: -5 (نقل‌قول از "ساکنان ناشناس")
────────────
امتیاز نهایی = 40 + 18 + 15 + 12 - 5 = 80 → سطح: HIGH → رنگ: سبز
حالت پردازش: REALTIME (آیتم جدید از RSS)
```

**تطابق با ADR:**

- ADR-0002: استفاده از GPT-5-nano برای استخراج اولیه
- ADR-0003: Batch processing برای historical analysis با SLA 24 ساعت

***

#### REQ-AI-002: خوشه‌بندی روایت‌ها (Narrative Clustering)

**داستان کاربر:**
به‌عنوان **کاربر**، می‌خواهم مقالات مرتبط درباره یک رویداد مشابه گروه‌بندی شوند تا تیترهای تکراری نبینم و بتوانم توسعه داستان را دنبال کنم.

**معیارهای پذیرش:**

1. **روش خوشه‌بندی:**
    - استفاده از **pgvector** برای شباهت معنایی
    - فاصله کسینوسی (cosine distance) روی embeddings با ۱۵۳۶ بُعد
    - مدل embedding: OpenAI `text-embedding-3-small`
2. **پنجره زمانی خوشه‌بندی:**
    - پیش‌فرض: ۱۴ روز
    - قابل تنظیم بر اساس نوع موضوع:
        - رویدادهای اعتراضی: ۲۱ روز
        - اخبار سیاسی: ۱۴ روز
        - موضوعات فرهنگی: ۷ روز
3. **شرایط تطابق (Match Conditions):**

دو آیتم به یک روایت تعلق دارند اگر:

```text
(شباهت_کسینوسی ≥ 0.85)
یا
(شباهت_کسینوسی ≥ 0.75 و همپوشانی_موجودیت ≥ 2)
```

    - **همپوشانی موجودیت:** تعداد موجودیت‌های مشترک از نوع PERSON، ORG، یا EVENT
    - آیتم‌هایی با `MainEventID` یکسان **همیشه** ادغام می‌شوند (حتی با موضع‌گیری‌های مخالف)
4. **تولید عنوان روایت:**
    - وقتی روایت جدیدی ایجاد می‌شود، **GPT-5-nano** (یا GPT-4o-mini برای موارد پیچیده) عنوان خلاصه تولید می‌کند
    - فرمت عنوان: `[رویداد اصلی]: [توسعه کلیدی]`
    - مثال: «اعتراضات زاهدان: شمار کشته‌شدگان به ۹۶ رسید»
5. **زمان‌بندی:**
    - خوشه‌بندی دسته‌ای هر ۱۵ دقیقه اجرا می‌شود
    - همگام با workflow دریافت داده

**الزامات عملکردی:**

- جستجوی برداری: ≤۲۰۰ms برای هر query
- استفاده از ایندکس HNSW روی `items.embedding` با پارامترهای:
    - `m = 16` (تعداد اتصالات هر نود)
    - `ef_construction = 64` (دقت ساخت ایندکس)
- تأخیر خوشه‌بندی: ≤۵ ثانیه برای هر آیتم جدید

**مثال:**

```text
آیتم جدید: "BBC: تعداد کشته‌شدگان اعتراضات زاهدان به 96 نفر رسید"
Embedding: [0.21, -0.15, 0.88, ...]

جستجو در آیتم‌های 14 روز گذشته:
1. "HRANA: 92 کشته در زاهدان تأیید شد" → شباهت: 0.91 ✅
2. "Iran International: زاهدان دوباره خونین شد" → شباهت: 0.78، موجودیت مشترک: 3 (زاهدان، اعتراضات، IRGC) ✅
3. "Tasnim: آرامش کامل در زاهدان" → شباهت: 0.72، موجودیت: 1 ❌

→ آیتم به Narrative موجود "اعتراضات زاهدان" اضافه می‌شود
```


***

#### REQ-AI-003: تشخیص منابع پروکسی (Proxy Detection)

**داستان کاربر:**
به‌عنوان **افسر اعتماد و ایمنی**، می‌خواهم سیستم رسانه‌های وابسته به دولت که خود را مستقل جا می‌زنند شناسایی کند تا نتوانند از طریق تأیید جعلی trust score را به‌طور مصنوعی افزایش دهند.

**معیارهای پذیرش:**

1. **فرمول محاسبه ProxyScore (۰-۱۰۰):**

```text
ProxyScore = (0.3 × ContentOverlap) + (0.3 × NarrativeAlign) + (0.2 × AmplificationNet) + (0.2 × TechOverlap)
```

2. **محاسبه اجزا:**


| جزء | توضیح | روش محاسبه |
| :-- | :-- | :-- |
| **ContentOverlap** (۰-۱۰۰) | همپوشانی محتوایی با منابع رژیم | درصد مقالاتی که شباهت کسینوسی ≥۰.۹۰ با منابع شناخته‌شده رژیم دارند |
| **NarrativeAlign** (۰-۱۰۰) | همسویی روایتی | درصد روایت‌هایی که منبع **هیچ‌وقت** با چارچوب‌بندی رژیم مخالفت نمی‌کند |
| **AmplificationNet** (۰-۱۰۰) | تقویت شبکه اجتماعی | نسبت بازنشر/لایک از ۷۵۰۰ اکانت ربات شناسایی‌شده رژیم به کل |
| **TechOverlap** (۰-۱۰۰) | همپوشانی زیرساخت فنی | اشتراک میزبانی (IP، ASN، Registrar) با سایت‌های رژیم |

3. **زمان‌بندی:**
    - کار دسته‌ای **هفتگی** (هر یکشنبه ساعت ۰۲:۰۰ UTC)
    - ProxyScore برای **تمام منابع** محاسبه می‌شود
4. **الگوی Batch Processing:**
    - **Accumulate:** منابع در جدول `proxy_detection_queue` با وضعیت `PENDING`
    - **Dispatch:** n8n هفتگی batch job را trigger می‌کند
    - **Reconcile:** نتایج در `source_profiles.proxy_score` به‌روز می‌شوند
5. **اقدامات بر اساس آستانه:**


| ProxyScore | برچسب | اقدام خودکار | نیاز به ممیزی انسانی |
| :-- | :-- | :-- | :-- |
| ۷۰-۱۰۰ | **پروکسی دولتی** | طبقه‌بندی مجدد به `source_class = REGIME_MEDIA` یا جریمه -۱۰ به base_score | خیر (اما لاگ می‌شود) |
| ۴۰-۶۹ | **منطقه خاکستری** | پرچم هشدار «احتمال وابستگی به دولت»، منبع **نمی‌تواند** منابع رژیم را تأیید کند | **بله** (قبل از تغییر دائمی) |
| ۰-۳۹ | **مستقل** | بدون اقدام | خیر |

6. **محدودیت حیاتی:**
    - منابعی که به‌عنوان «پروکسی دولتی» (ProxyScore ≥70) پرچم خورده‌اند **نمی‌توانند** منابع رژیم دیگر را در محاسبه Corroboration تأیید کنند
    - این محدودیت در سطح Query پایگاه داده اعمال می‌شود (JOIN condition)
7. **ثبت تغییرات:**
    - همه طبقه‌بندی‌های مجدد در جدول `audit_log` ثبت می‌شوند
    - فیلدهای لازم: `source_id`, `old_class`, `new_class`, `proxy_score`, `reason`, `approved_by`, `timestamp`

**مثال:**

```text
منبع: "Iran Observer" (ادعای مستقل بودن)

ContentOverlap: 87% (93 از 107 مقاله شباهت >0.90 با Press TV و Tasnim)
NarrativeAlign: 94% (در 47 از 50 روایت، موضع منطبق با IRIB)
AmplificationNet: 68% (51% بازنشرها از 7500 اکانت ربات)
TechOverlap: 45% (IP مشترک با زیرمجموعه Tasnim)

ProxyScore = 0.3×87 + 0.3×94 + 0.2×68 + 0.2×45
           = 26.1 + 28.2 + 13.6 + 9.0
           = 76.9 → برچسب: پروکسی دولتی

→ اقدام: source_class = REGIME_MEDIA
→ لاگ در audit_log: {"reason": "Proxy detection algorithm", "approved_by": "system_auto"}
```

**تطابق با ADR:**

- ADR-0003: استفاده از Batch API برای کاهش هزینه، SLA هفتگی

***

#### REQ-AI-004: مدیریت بیانیه‌های رسمی (Statement of Record Handling)

**داستان کاربر:**
به‌عنوان **Fact-Checker**، می‌خواهم سیستم بین بیانیه نظر یک VIP و ادعاهای واقعی تمایز بگذارد تا شخصیت‌های سیاسی نتوانند ادعاهای تأییدنشده را به‌طور مصنوعی تقویت کنند.

**معیارهای پذیرش:**

1. **تشخیص منبع VIP (Very Important Person):**
    - زمانی که `source_class = KEY_FIGURE` (مثال‌ها: Donald Trump، Masoud Pezeshkian، Reza Pahlavi)
    - یا `is_verified_account = TRUE` و `follower_count > 100000`
2. **دسته‌بندی محتوای VIP:**


| نوع محتوا | تشخیص | پردازش |
| :-- | :-- | :-- |
| **بیانیه رسمی** | الگوهای زبانی: «من خواهم...»، «ما برنامه داریم...»، «من محکوم می‌کنم...»، «دولت من...» | `is_official_statement = TRUE`، امتیاز اعتماد = امتیاز اصالت (Authenticity Score) |
| **ادعای واقعی** | الگوهای عددی: «X نفر کشته شدند»، «Y تومان...»، «آن‌ها به ما حمله کردند» | `is_official_statement = FALSE`، نیاز به تأیید متقابل از منابع مستقل |

3. **محاسبه امتیاز اصالت (Authenticity Score):**
    - کانال رسمی تأییدشده (Official Twitter، کانال Telegram دولتی): +20
    - اکانت Verified: +10
    - ویدیو/صوت تأیید هویت: +5
    - بدون تأیید: +0
4. **قانون اصلی:**
> **وضعیت VIP امتیاز حقیقت (Truth Score) ادعاهای واقعی را افزایش نمی‌دهد**
    - فقط تأیید متقابل از منابع مستقل (NGO، Wire Services، تحقیقات مستقل) امتیاز را افزایش می‌دهد
    - اگر ادعای عددی تأیید نشود، امتیاز در محدوده LOW/MEDIUM باقی می‌ماند (≤50)
5. **پرچم‌گذاری:**
    - ادعاهای تأییدنشده با برچسب `UNVERIFIED_CLAIM` علامت‌گذاری می‌شوند
    - نمایش هشدار در UI: «این ادعا توسط منابع مستقل تأیید نشده است»

**مثال کامل:**

```text
توییت Trump: "I convinced the Iranian regime to cancel 800 executions"

تحلیل:
├─ بخش 1: "I convinced..." → بیانیه نظر شخصی
│  └─ is_official_statement = TRUE
│  └─ امتیاز اصالت = 30 (کانال رسمی +20، Verified +10)
│
└─ بخش 2: "800 executions cancelled" → ادعای عددی واقعی
   ├─ is_official_statement = FALSE
   ├─ جستجوی تأیید متقابل:
   │  ├─ Iran Human Rights (NGO): هیچ تأییدی ندارد ❌
   │  ├─ Amnesty International: هیچ گزارشی از لغو گسترده ❌
   │  └─ Reuters/AP: هیچ خبری ❌
   │
   └─ محاسبه امتیاز:
      ├─ پایه: 25 (KEY_FIGURE، اما نه رسانه حرفه‌ای)
      ├─ منشأ: 10 (اکانت رسمی، timestamp معتبر)
      ├─ تأیید متقابل: 0 (هیچ منبع مستقلی تأیید نکرد)
      ├─ شفافیت: 0 (بدون لینک به منبع)
      ├─ تعدیل: -10 (ادعای عددی بدون سند)
      └─ امتیاز نهایی = 25 → LOW (قرمز)
      
→ نمایش در UI:
  Trust Score: 25 (پایین)
  هشدار: "این ادعا درباره '800 اعدام' توسط سازمان‌های حقوق بشری تأیید نشده است"
  وضعیت بیانیه: "بیانیه رسمی دونالد ترامپ" (با نشان Verified)
```


***

### ۱.۳ ماژول: لایه API محصول (Product API Layer)

#### REQ-API-001: نقطه پایانی خوراک عمومی (Public Feed Endpoint)

**داستان کاربر:**
به‌عنوان **توسعه‌دهنده فرانت‌اند**، می‌خواهم یک endpoint feed که روایت‌ها را با آیتم‌های تودرتو برمی‌گرداند تا بتوانم آخرین اخبار را در صفحه اصلی نمایش دهم.

**مشخصات فنی:**

1. **Endpoint:** `GET /api/v1/feed`
2. **پارامترهای Query:**


| پارامتر | نوع | پیش‌فرض | محدوده | توضیح |
| :-- | :-- | :-- | :-- | :-- |
| `limit` | INT | 20 | 1-100 | تعداد روایت‌های برگشتی |
| `offset` | INT | 0 | ≥0 | برای صفحه‌بندی (pagination) |
| `language` | ENUM | EN | EN, FA, AR | فیلتر بر اساس زبان اصلی |
| `min_trust_score` | INT | 40 | 15-95 | حداقل امتیاز اعتماد |
| `source_class` | STRING | (همه) | REGIME_MEDIA, NGO_WATCHDOG, INTL_WIRE, ... | فیلتر بر اساس کلاس منبع (اختیاری) |

3. **طرح پاسخ (Response Schema):**
```json
{
  "narratives": [
    {
      "narrative_id": "uuid",
      "title": "اعتراضات زاهدان: شمار کشته‌شدگان به ۹۶ رسید",
      "title_en": "Zahedan Protests: Death Toll Reaches 96",
      "summary": "تولیدشده توسط AI: اعتراضات در زاهدان پس از نماز جمعه آذرماه آغاز شد...",
      "summary_en": "AI-generated: Protests in Zahedan began after Friday prayers...",
      "created_at": "2026-02-03T10:00:00Z",
      "last_updated": "2026-02-03T11:00:00Z",
      "item_count": 12,
      "avg_trust_score": 72,
      "trust_distribution": {
        "high": 7,
        "medium": 4,
        "low": 1
      },
      "top_items": [
        {
          "item_id": "uuid",
          "title": "HRANA گزارش می‌دهد: ۹۶ کشته در زاهدان",
          "title_en": "HRANA reports: 96 killed in Zahedan",
          "source_name": "خبرگزاری فعالان حقوق بشر (HRANA)",
          "source_name_en": "Human Rights Activists News Agency",
          "source_logo_url": "https://cdn.nura.ai/logos/hrana.png",
          "publish_date": "2026-02-03T09:30:00Z",
          "trust_score": 85,
          "trust_level": "HIGH",
          "url": "https://www.en-hrana.org/zahedan-96-killed",
          "language": "FA"
        }
      ]
    }
  ],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "has_next": true,
    "has_previous": false
  },
  "meta": {
    "generated_at": "2026-02-03T11:05:23Z",
    "cache_ttl": 120,
    "api_version": "v1.0"
  }
}
```

4. **الزامات عملکردی:**
    - زمان پاسخ: ≤۵۰۰ms (P95)
    - کشینگ: Redis cache با TTL دو دقیقه
    - صفحه‌بندی: پشتیبانی از offset/limit برای لود تدریجی
5. **کدهای خطا:**


| کد HTTP | توضیح |
| :-- | :-- |
| 200 | موفقیت |
| 400 | پارامترهای نامعتبر (مثلاً limit>100) |
| 429 | تعداد درخواست‌های بیش از حد (rate limit) |
| 500 | خطای سرور داخلی |


***

#### REQ-API-002: نقطه پایانی جزئیات آیتم (Item Detail Endpoint)

**داستان کاربر:**
به‌عنوان **کاربر**، می‌خواهم روی یک آیتم خبری کلیک کنم و مقاله کامل را با تفکیک trust score ببینم تا بفهمم چرا امتیاز بالا یا پایین است.

**مشخصات فنی:**

1. **Endpoint:** `GET /api/v1/items/{item_id}`
2. **پارامترهای مسیر:**
    - `item_id` (UUID): شناسه منحصربه‌فرد آیتم
3. **طرح پاسخ (Response Schema):**
```json
{
  "item_id": "e7b3c4d5-6f8a-4b2c-9d1e-3a5f7c8b9e0d",
  "title": "HRANA گزارش می‌دهد: ۹۶ کشته در اعتراضات زاهدان",
  "title_en": "HRANA reports: 96 killed in Zahedan protests",
  "body_text": "خبرگزاری فعالان حقوق بشر ایران (HRANA) امروز گزارش داد که شمار کشته‌شدگان اعتراضات زاهدان به ۹۶ نفر رسیده است...",
  "body_en": "The Human Rights Activists News Agency (HRANA) reported today that the death toll from the Zahedan protests has reached 96...",
  "language": "FA",
  "translation_quality": {
    "method": "GPT-5-nano",
    "confidence": 0.92,
    "human_verified": false
  },
  "source": {
    "source_id": "uuid",
    "name": "خبرگزاری فعالان حقوق بشر",
    "name_en": "Human Rights Activists News Agency (HRANA)",
    "logo_url": "https://cdn.nura.ai/logos/hrana.png",
    "source_class": "NGO_WATCHDOG",
    "base_score": 90,
    "website": "https://www.en-hrana.org"
  },
  "metadata": {
    "author": "گروه گزارشگری HRANA",
    "author_en": "HRANA Reporting Team",
    "publish_date": "2026-02-03T09:30:00Z",
    "url": "https://www.en-hrana.org/zahedan-96-killed",
    "raw_html_url": "https://blob.nura.ai/raw/hrana/2026-02-03/abc123.html",
    "entities": [
      {"type": "PERSON", "name": "مهسا امینی", "name_en": "Mahsa Amini", "confidence": 0.95},
      {"type": "EVENT", "name": "اعتراضات زاهدان", "name_en": "Zahedan Protests", "confidence": 0.98},
      {"type": "LOCATION", "name": "زاهدان", "name_en": "Zahedan", "coordinates": [60.86, 29.49]}
    ],
    "media_attachments": [
      {
        "type": "image",
        "url": "https://cdn.nura.ai/media/item123/photo1.jpg",
        "caption": "تصویر اعتراضات زاهدان",
        "caption_en": "Image of Zahedan protests",
        "verified": true
      }
    ]
  },
  "trust_signal": {
    "final_score": 85,
    "trust_level": "HIGH",
    "processing_mode": "REALTIME",
    "badges": ["VERIFIED_SOURCE", "CORROBORATED", "PRIMARY_DOCUMENTS"],
    "breakdown": {
      "base": 40,
      "provenance": 20,
      "corroboration": 18,
      "transparency": 12,
      "modifiers": -5
    },
    "breakdown_details": {
      "base": {
        "score": 40,
        "reason": "منبع NGO با سابقه قوی (base_score=90 از جدول source_profiles)",
        "reason_en": "NGO source with strong track record (base_score=90 from source_profiles)"
      },
      "provenance": {
        "score": 20,
        "components": {
          "url_validity": 5,
          "timestamp": 3,
          "author_byline": 4,
          "dateline": 3,
          "media_attached": 5
        }
      },
      "corroboration": {
        "score": 18,
        "sources": [
          {"name": "BBC Persian", "similarity": 0.88, "trust_level": "HIGH"},
          {"name": "Iran Human Rights", "similarity": 0.91, "trust_level": "HIGH"}
        ],
        "count": 2
      },
      "transparency": {
        "score": 12,
        "editorial_disclosure": true,
        "corrections_policy_url": "https://www.en-hrana.org/corrections"
      },
      "modifiers": {
        "score": -5,
        "red_flags": [
          {"type": "ANONYMOUS_SOURCE", "penalty": -5, "description": "نقل‌قول از 'ساکنان محلی' بدون نام"}
        ],
        "green_flags": []
      }
    },
    "explanation": "این گزارش امتیاز اعتماد بالایی دارد زیرا: (
<span style="display:none">[^1][^10][^2][^3][^4][^5][^6][^7][^8][^9]</span>

<div align="center">⁂</div>

[^1]: srs-nura-v2.4.md
[^2]: Iran Propaganda Archive Jan2026
[^3]: 01-discovery-and-planning.md
[^4]: 02-requirements.md
[^5]: 03-architecture-overview.md
[^6]: 04-ai-engineering.md
[^7]: NN-ADR-0002-cost-optimization.md
[^8]: NN-ADR-0001-sql-first-migrations.md
[^9]: NN-ADR-0004-translation-strategy.md
[^10]: NN-ADR-0003-batch-processing.md```

