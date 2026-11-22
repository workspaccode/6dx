# تصميم المجموعات والأدوار (Software / Hardware)

> **الحالة:** القرارات اتحسمت (القسم 12)، والتنفيذ لسه مابدأش.
> **المدخلات:** الكود الحالي على فرع `v5.0`، والبحث اللي في آخر الملف (Stage-Gate، EVT/DVT/PVT، ECO، و GitHub Teams، Linear، Jira، ClickUp، Arena، Duro).

## 1. الفكرة في سطرين

**التيم ليد** بيعمل **مجموعة** نوعها **Software** أو **Hardware**. المجموعة فيها **مشاريع**، والتيم ليد بيضيف تحتها **مساعدين** (أدمن المجموعة) و**أعضاء**، وكل عضو ليه **دور وظيفي** حسب نوع المجموعة: مبرمج، reviewer، QA في الـ Software، أو مهندس كهربا، firmware، فني، مشتريات في الـ Hardware. ولكل نوع **طريقة إدارة مشاريع خاصة بيه**: الـ Software ماشي بـ tasks و sprints و PRs، والـ Hardware ماشي بمراحل (EVT/DVT/PVT) و BOM و ECO و builds واختبارات.

## 2. الوضع الحالي

| الموجود | الملاحظة |
|---|---|
| `workspaces` ← `workspace_members(role)` ← `projects` | مستوى واحد. المشاريع تحت الـ workspace على طول |
| أدوار ثابتة: `owner`، `admin`، `developer`، `reviewer`، `viewer` | كلها Software. مفيش أي دور Hardware |
| `IsAdmin()` و `IsEditor()` في [`authz.go:35-36`](../../backend/internal/api/authz.go#L35) | صلاحيات على شكل "مستويات" مش "قدرات" |
| `/invite/accept` من غير id في الرابط | بيقبل "أحدث دعوة" ([04-backend.md](../review/04-backend.md)) |
| الـ redirect بيفرّق بين مسجّل ومش مسجّل بس | مفيش حراسة حسب الدور ([02-routing.md](../review/02-routing.md)) |

---

## 3. الهيكل المقترح

```
Workspace (الشركة / الحساب — tenant)
 └── Group (التيم)  type = software | hardware
      ├── Group members  (group_role + functional_role)
      └── Project
           └── Project members (override اختياري)
```

### القرار 1: المجموعة مستوى جديد تحت الـ Workspace

- المجموعات **مستقلة عن بعض** في العادي. الربط بين مجموعة Hardware ومجموعة Software **حالة استثنائية**، وبيتم بـ **ربط مشروع** صريح (القسم 3.1)، مش بدمج المجموعات.
- مسكنا المجموعة تحت الـ workspace (مش هي الـ workspace نفسه) علشان الربط الاستثنائي ده يفضل جوه نفس الـ tenant. الربط بين workspaces مختلفة ممنوع.
- كل الأدوات الكبيرة ماشية على نفس الشكل: GitHub (Org ← Team)، Linear (Workspace ← Team)، ClickUp (Workspace ← Space).
- **الـ workspace الشخصي اللي بيتعمل تلقائي** بيفضل زي ما هو، وجواه مجموعة افتراضية واحدة نوعها Software. كده البيانات الحالية بتتنقل من غير ما حاجة تتكسر (القسم 10).
- **حدود الخطة بتتحسب على مستوى الـ workspace** (القسم 3.2).

### القرار 2: المجموعة فيها أكتر من مشروع

المجموعة = **التيم**، والمشروع = **منتج أو نسخة من منتج** (مثلًا Power Board v1 و v2، أو variant لسوق معين).

- **ليه مش مشروع واحد؟**
  - التيم بيشتغل عادةً على أكتر من منتج، أو على الإصدار الجاي وهو لسه بيدعم الحالي.
  - المراحل والحالات والـ approval matrix بتتعرّف **مرة واحدة** على مستوى المجموعة وكل المشاريع بتستخدمها (القرار 3). لو كل مجموعة مشروع واحد، هتعيد الإعداد ده مع كل منتج جديد.
  - المخزن والموردين مشتركين بين مشاريع المجموعة (القسم 7.5).
- **علشان التجربة متبقاش تقيلة:** لو المجموعة فيها **مشروع واحد بس**، `/g/:gid/projects` بيعمل redirect على طول لـ `/g/:gid/p/:pid`، ومفيش قائمة مشاريع في الـ navigation. القائمة بتظهر تلقائي من تاني مشروع.
- مفيش حد لعدد المشاريع في المجموعة.

### القرار 3: المراحل والحالات قابلة للتعديل على مستوى المجموعة

- الـ lead أو الـ admin يقدر يضيف ويعدّل ويرتب ويحذف **المراحل** (Hardware) و**حالات المهام** (النوعين) و**حالات الـ ECO والـ build**، و**شروط الـ gates**.
- القالب اللي بيتختار وقت إنشاء المجموعة (EVT/DVT/PVT، Scrum، Kanban) **نقطة بداية بس**.
- التفاصيل في القسم 7.1 و 7.3.

### قواعد

1. **مستويين بس** (Group ← Project). مفيش sub-groups في الـ MVP. المصادر بتحذّر من "inheritance creep" لما الـ nesting يزيد.
2. المستخدم يقدر يبقى في **أكتر من مجموعة بأدوار مختلفة**. العضوية بتتخزن لكل مجموعة لوحدها.
3. عضو المجموعة لازم يكون عضو في الـ workspace. لما يقبل دعوة مجموعة بيتضاف للـ workspace بدور `member` تلقائي.
4. **مفيش وراثة بين workspaces مختلفة** أبدًا.
5. نوع المجموعة **مش بيتغير** بعد إنشائها. نفس قاعدة Jira: الـ Software والـ Hardware ليهم كيانات مختلفة، والتحويل محتاج migration.
6. ينفع مجموعة Hardware يكون فيها مشروع **firmware** متوصل بـ GitHub، وده الكوبري العادي بين النوعين (القسم 7.4). وده من غير أي ربط بين مجموعات.

### 3.1 ربط المشاريع بين المجموعات (حالة استثنائية)

لما مشروع في مجموعة Software (مثلًا تطبيق الموبايل) يكون معتمد على مشروع في مجموعة Hardware (مثلًا الجهاز نفسه):

- **الربط بيتطلب من طرف ويتوافق عليه من الطرف التاني.** الـ lead أو الـ admin في المجموعة الأولى يطلب، والـ lead أو الـ admin في المجموعة التانية يوافق. ولازم المجموعتين في **نفس الـ workspace**.
- **الربط بيدّي رؤية بس، مش عضوية.** أعضاء كل مجموعة بيشوفوا من المشروع التاني **ملخص**: المرحلة الحالية، الـ releases، مصفوفة التوافق firmware ↔ HW، والـ milestones. لكن مش بيشوفوا المهام ولا الـ BOM ولا الأسعار ولا الأعضاء.
- ينفع ربط مهمة بمهمة (dependency) عبر الربط ده، وكل طرف بيشوف عنوان المهمة التانية وحالتها بس.
- أي طرف يقدر يلغي الربط في أي وقت.
- الربط **لاحقًا** (المرحلة 5). المجموعات بتشتغل كاملة من غيره.

```sql
create table project_links (
  id            text primary key,
  from_project  text not null references projects (id) on delete cascade,
  to_project    text not null references projects (id) on delete cascade,
  status        text not null check (status in ('requested', 'active', 'revoked')),
  requested_by  text references users (uid),
  approved_by   text references users (uid),
  created_at    text not null,
  unique (from_project, to_project)
);
-- الـ API بيشيّك إن المشروعين في نفس الـ workspace
```

### 3.2 حدود الخطط

| | الخطة العادية | الخطة المدفوعة |
|---|---|---|
| **السعر** | مجانًا | **60 دولار / شهر** |
| **عدد المجموعات في الـ workspace** | **10** | **50** |
| عدد الأعضاء | مفتوح | مفتوح |
| عدد المشاريع في المجموعة | مفتوح | مفتوح |

**قواعد التطبيق:**

- الحد بيتشيّك **في السيرفر** جوه نفس الـ transaction اللي بتعمل المجموعة (`BEGIN IMMEDIATE`، وبعدها count، وبعدها insert). من غير كده طلبين في نفس اللحظة يعدّوا الحد، وده نفس الـ race اللي في إنشاء الـ workspace ([04-backend.md](../review/04-backend.md)).
- **المجموعات المأرشفة مش بتتحسب.** بس مينفعش تفك الأرشفة لو هتعدّي الحد.
- **لو الخطة نزلت من المدفوعة للعادية** والمجموعات أكتر من 10: مفيش حاجة بتتمسح، وكل المجموعات الموجودة بتفضل شغالة، بس **مينفعش تعمل مجموعة جديدة** لحد ما العدد ينزل تحت 10.
- الحد متخزن في جدول الخطط (مش ثابت في الكود)، علشان لو اتغير مايحتاجش deploy.
- الـ UI: عداد "7 / 10 مجموعات" في `/groups`. ولما توصل للحد، زر "+ مجموعة جديدة" بيفتح شاشة الترقية بدل الـ wizard.
- كود الخطأ من السيرفر: `group_limit_reached`.

```sql
create table plans (
  id          text primary key,          -- 'free' | 'pro'
  max_groups  integer not null           -- 10 | 50
);
alter table workspaces add column plan_id text not null default 'free' references plans (id);
```

---

## 4. الأدوار

كل عضو عنده **دورين**:

| | المعنى | مين بيحدده |
|---|---|---|
| **`group_role`** | سلطته الإدارية على المجموعة | التيم ليد / المساعد |
| **`functional_role`** | شغلانته، وبيحدد الصلاحيات التشغيلية والشاشة الرئيسية بتاعته | التيم ليد / المساعد |

### 4.1 الأدوار الإدارية (مشتركة بين النوعين)

| `group_role` | بالعربي | يقدر |
|---|---|---|
| `lead` | التيم ليد (صاحب المجموعة) | كل حاجة، ومنها حذف المجموعة ونقل الملكية وقرار الـ gate |
| `admin` | مساعد | يدير الأعضاء والمشاريع والإعدادات. **مش بيقدر** يحذف المجموعة، ولا يغيّر دور الـ lead، ولا يرقّي حد لـ admin (نفس قاعدة الـ owner الحالية) |
| `member` | عضو | حسب الدور الوظيفي |
| `guest` | ضيف / عميل | يقرا المشاريع اللي اتشاركت معاه بس، من غير إيميلات الفريق ولا الأسعار ([03-security.md](../review/03-security.md) بند 16) |

> أدوار الـ workspace بتتبسط لـ `owner` و `admin` و `member`. الـ owner والـ admin بتوع الـ workspace بيشوفوا كل المجموعات وبيعملوها، بس **مش بياخدوا صلاحيات تشغيلية** جوه المجموعة تلقائي (فصل المهام). ممكن يضيفوا نفسهم.

### 4.2 الأدوار الوظيفية — Software

| `functional_role` | بالعربي |
|---|---|
| `tech_lead` | قائد تقني |
| `developer` | مبرمج |
| `reviewer` | مراجع كود |
| `qa` | اختبار جودة |
| `designer` | مصمم UI/UX |
| `devops` | DevOps |
| `pm` | مدير منتج / مشروع |
| `client` | العميل (دايمًا `group_role = guest`) |

### 4.3 الأدوار الوظيفية — Hardware

| `functional_role` | بالعربي | MVP؟ |
|---|---|---|
| `hw_lead` | قائد الهاردوير | ✅ |
| `electrical` | مهندس كهربا / إلكترونيات (ومعاه الـ PCB layout) | ✅ |
| `mechanical` | مهندس ميكانيكا | ✅ |
| `firmware` | مهندس firmware | ✅ |
| `test` | مهندس اختبار / جودة (ومعاه الـ compliance) | ✅ |
| `technician` | فني (تجميع، bring-up، قياسات) | ✅ |
| `manufacturing` | مهندس تصنيع / NPI | لاحقًا |
| `procurement` | مشتريات / سلسلة إمداد | ✅ (مع المرحلة 4ب) |
| `client` | العميل | ✅ |

### 4.4 الصلاحيات = قدرات، مش مستويات

بدل `IsEditor()`، كل endpoint بيطلب **قدرة** (capability)، وكل دور عنده **مجموعة قدرات**. ده بيسهّل إضافة custom roles بعدين من غير ما الكود يتغير.

```go
type Capability string

const (
    CapManageMembers  Capability = "members.manage"
    CapManageProjects Capability = "projects.manage"
    CapEditTasks      Capability = "tasks.edit"
    CapPlanSprints    Capability = "sprints.plan"
    CapReviewPR       Capability = "pr.review"
    CapMergePR        Capability = "pr.merge"
    CapQAPass         Capability = "qa.pass"
    CapEditBOM        Capability = "bom.edit"
    CapReleaseBOM     Capability = "bom.release"
    CapSubmitECO      Capability = "eco.submit"
    CapApproveECO     Capability = "eco.approve"   // + المرحلة من approval matrix
    CapManageBuilds   Capability = "builds.manage"
    CapRecordTests    Capability = "tests.record"
    CapApproveTests   Capability = "tests.approve"
    CapGateDecision   Capability = "gate.decide"
    CapViewFinance    Capability = "finance.view"
    CapManageWorkflow Capability = "workflow.manage" // الحالات والمراحل
    CapManageVendors  Capability = "vendors.manage"
    CapCreatePO       Capability = "po.create"
    CapApprovePO      Capability = "po.approve"
    CapMoveInventory  Capability = "inventory.move"
)

// requireCap(ctx, groupID, projectID, uid, cap) → effective role → allowed?
```

### 4.5 مصفوفة الصلاحيات — Software

✓ = يقدر · ◐ = بتاعه أو المتعيّن عليه بس · R = قراءة بس · – = لأ

| القدرة | lead | admin | tech_lead | developer | reviewer | qa | designer | devops | client |
|---|---|---|---|---|---|---|---|---|---|
| إدارة الأعضاء | ✓ | ✓ | – | – | – | – | – | – | – |
| إنشاء / أرشفة مشروع | ✓ | ✓ | ✓ | – | – | – | – | – | – |
| إنشاء / تعديل مهام | ✓ | ✓ | ✓ | ✓ | ◐ | ✓ | ◐ | ◐ | – |
| تخطيط الـ sprint | ✓ | ✓ | ✓ | – | – | – | – | – | – |
| مراجعة / اعتماد PR | ✓ | – | ✓ | ✓ (مش بتاعه) | ✓ | – | – | – | – |
| Merge | ✓ | – | ✓ | – | ✓ | – | – | ✓ | – |
| تعليم "QA passed" | ✓ | – | ✓ | – | – | ✓ | – | – | – |
| الـ repos والتكاملات | ✓ | ✓ | ✓ | – | – | – | – | ✓ | – |
| قرار العميل | – | override | – | – | – | – | – | – | ✓ |
| الأسعار والفواتير | ✓ | ✓ | – | – | – | – | – | – | R (بتاعته) |
| متابعة التقدم | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | R |

### 4.6 مصفوفة الصلاحيات — Hardware

| القدرة | lead / hw_lead | admin | electrical / mechanical | firmware | test | technician | manufacturing | procurement | client |
|---|---|---|---|---|---|---|---|---|---|
| إدارة الأعضاء | ✓ | ✓ | – | – | – | – | – | – | – |
| إنشاء parts / تعديل BOM مسودة | ✓ | – | ✓ | ◐ | – | – | ✓ | R | – |
| **Release لـ BOM revision** | ✓ | – | – | – | – | – | – | – | – |
| تقديم ECR/ECO | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (طلب بس) | ✓ | ✓ | – |
| **اعتماد ECO — مرحلة التصميم** | ✓ | – | ✓ (لو متعيّن) | ✓ (لو متعيّن) | – | – | – | – | – |
| **اعتماد ECO — مرحلة الإنتاج** | ✓ | – | – | – | ✓ | – | ✓ | ✓ (تكلفة / مخزون) | – |
| إنشاء build / توزيع وحدات | ✓ | ✓ | ✓ | – | ✓ | – | ✓ | – | – |
| تسجيل نتايج اختبار على وحدة | ✓ | – | ✓ | ✓ | ✓ | ✓ | ✓ | – | – |
| اعتماد test plan / نجاح اختبار الـ gate | ✓ | – | – | – | ✓ | – | – | – | – |
| **قرار الـ gate (Go / Recycle / Hold / Kill)** | ✓ | – | – | – | – | – | – | – | – |
| ربط firmware release ↔ HW revision | ✓ | – | ✓ | ✓ | – | – | – | – | – |
| متابعة المراحل والـ gates | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | R |

**أعمدة الاعتماد** (ECO، release الـ BOM، الـ gate) بتيجي من **approval matrix** متخزنة لكل مجموعة، مش مكتوبة ثابتة في الكود. الـ MVP بيبدأ بالقيم الافتراضية اللي فوق، وشاشة تعديلها تيجي بعدين.

### 4.7 الوراثة والـ override

```
effective_role(user, project) =
    project_members.role          لو موجود (override)
    else group_members.role       (وراثة من المجموعة)
    else لا يوجد وصول

استثناء: group_role ∈ {lead, admin} ← دايمًا admin على كل مشاريع المجموعة
```

- الـ override ممكن **يرفع** دور (فني بقى `test` في مشروع معين) أو **ينزّله** (مبرمج read-only على مشروع حساس).
- الـ `guest` **مش بيورث** أي مشروع. لازم كل مشروع يتشارك معاه صراحة (نفس قاعدة ClickUp).
- **مشروع خاص** (`visibility = private`): أعضاء المجموعة مش بيشوفوه غير لو اتضافوا عليه.

---

## 5. رحلة المستخدم

### 5.1 التيم ليد بيعمل مجموعة

```
/groups  →  [+ مجموعة جديدة]  →  /groups/new
   1. الاسم + الوصف + الأيقونة
   2. النوع: Software | Hardware            (مش بيتغير بعدين)
   3. القالب:
        Software: Scrum | Kanban
        Hardware: EVT/DVT/PVT | مراحل مخصصة
   4. دعوة الأعضاء (اختياري، ممكن تتأجل): إيميل + group_role + functional_role
→ /g/:gid/home  (التيم ليد بيبقى lead تلقائي)
```

### 5.2 الدعوة والانضمام (أهم مسار في الراوت)

الدعوة بتبقى **لمجموعة معينة وبدور محدد مسبقًا**، والرابط فيه **id الدعوة** (مش "أحدث دعوة").

```
الإيميل / الإشعار:  "أحمد دعاك لـ «تيم الـ Power Board» كـ «فني»"
          │
          ▼
/invite/:inviteId
          │
   مش مسجّل؟ ──► /login?from=/invite/:inviteId ──► (بعد الدخول) ──┐
          │                                                         │
          ▼◄────────────────────────────────────────────────────────┘
   GET /v1/invites/:id   (الإيميل لازم يطابق إيميل مُوثّق للمستخدم)
          │
   ├─ منتهية / ملغية    → /invite/:id/expired   (زر "اطلب دعوة جديدة")
   ├─ مش ليك            → /invite/:id/mismatch  ("الدعوة دي لـ x@y.com — بدّل الحساب")
   ├─ مقبولة قبل كده    → /g/:gid/home
   └─ صالحة             → شاشة القبول: اسم المجموعة + النوع + دورك + مين دعاك
                              [قبول]                [رفض]
                                │                     │
                                ▼                     ▼
             POST /v1/invites/:id/accept       POST .../decline → /groups
                                │
                      activeGroup = gid  (مباشرة، مش resolve())
                                │
                                ▼
                     /g/:gid/welcome   (أول مرة بس)
                       checklist: الملف الشخصي · الإشعارات · أول خطوة حسب دورك
                                │
                                ▼
                     /g/:gid/home  ← الشاشة الرئيسية حسب الدور (5.4)
```

### 5.3 فتح التطبيق: هيروح فين؟

```
مسجّل؟
 ├─ لأ                                  → /login (مع ?from= لو فيه deep link)
 └─ أيوه
     ├─ فيه دعوات معلّقة؟                → /groups (بانر "عندك دعوة")
     ├─ عدد المجموعات = 0               → /groups/empty  ("اعمل مجموعة" أو "مستني دعوة")
     ├─ عدد المجموعات = 1               → /g/:gid/home
     └─ أكتر من مجموعة                  → /g/<آخر مجموعة فتحتها>/home
                                          (لو اتشال منها → /groups + رسالة)
```

### 5.4 الشاشة الرئيسية حسب الدور

`/g/:gid/home` مسار واحد، والـ widget بيختار المحتوى حسب `functional_role`:

| الدور | أول حاجة يشوفها |
|---|---|
| lead / hw_lead | اعتمادات ECO مستنياه، جاهزية الـ gate الجاية، المخاطر |
| tech_lead | الـ sprint الحالي، PRs محتاجة مراجعة، CI فاشل |
| developer | مهامي، PRs مستنية مراجعتي |
| reviewer | طابور المراجعة + الـ SLA |
| qa / test | اختبارات مطلوبة، الوحدات الفاشلة، test plans |
| electrical / mechanical | مهامي في التصميم، ECOs بتاعتي، الـ BOM المسودة |
| firmware | مهامي + الـ PRs + مصفوفة التوافق مع الـ HW |
| technician | طابور الـ builds، الوحدات المتعيّنة عليا، تسجيل نتيجة سريع |
| procurement | قطع طويلة التوريد، أوامر الشراء المفتوحة (لاحقًا) |
| client / guest | تقدم المراحل / الـ milestones، التقارير، القرار المطلوب منه |

### 5.5 التبديل بين المجموعات

- **الموبايل:** اسم المجموعة في الـ AppBar، ولما تدوس عليه يفتح bottom sheet فيه "مجموعاتي" (badge للنوع HW/SW + دورك) و "+ مجموعة جديدة".
- **الديسكتوب / الويب:** switcher في أعلى الـ sidebar.
- التبديل = `context.go('/g/$newGid/home')`. الـ `gid` في الرابط **هو مصدر الحقيقة**، مش state مخفي. كده بنحل مشكلة "الـ workspace بعد قبول الدعوة" من أساسها، والـ refresh في الويب والـ deep links بيشتغلوا.
- عند التبديل: `githubSdk.reset()` وأي كاش مربوط بالمجموعة ([03-security.md](../review/03-security.md) بند 13).

### 5.6 حالات لازم تتغطى

| الحالة | السلوك |
|---|---|
| اتشلت من المجموعة وانت جواها | الطلب الجاي بيرجع `403 not_group_member`، فيظهر "اتشلت من المجموعة" ويوديك على `/groups` |
| دورك اتغير | invalidate لـ `groupAccessProvider(gid)`، والشاشة تتبني تاني والأزرار تتقفل/تتفتح |
| المجموعة اتحذفت أو اتأرشفت | `/groups` + رسالة |
| فتحت رابط لمشروع خاص مش متضاف عليه | `NoPermissionPage` + زر "اطلب وصول" |
| guest فتح `/g/:gid/members` | redirect لـ `/g/:gid/home` |
| الدعوة لإيميل غير إيميل حسابك | `/invite/:id/mismatch` |
| الـ lead عايز يسيب المجموعة | لازم ينقل الملكية الأول |

---

## 6. الراوت (go_router)

### 6.1 شجرة المسارات

```
/                                   splash
/login?from=…
/onboarding
/invite/:inviteId                   قبول / رفض
/invite/:inviteId/expired
/invite/:inviteId/mismatch

/groups                             مجموعاتي + الدعوات المعلّقة
/groups/new                         إنشاء مجموعة (wizard)
/groups/empty

/g/:gid                             → redirect لـ /g/:gid/home
/g/:gid/welcome
/g/:gid/home                        الرئيسية حسب الدور
/g/:gid/members                     [members.manage للتعديل]
/g/:gid/members/invite              [members.manage]
/g/:gid/settings                    [lead | admin]
/g/:gid/settings/roles              مصفوفة الصلاحيات / الاعتمادات
/g/:gid/settings/workflow           حالات المهام (+ حالات الـ ECO والـ build في Hardware)
/g/:gid/settings/phases             [hardware] المراحل وشروط الـ gates
/g/:gid/settings/plan               الخطة والعداد (7 / 10)
/g/:gid/inventory                   [hardware] المخزن المشترك: الأرصدة والحركات
/g/:gid/inventory/:partNumber
/g/:gid/vendors                     [hardware] الموردين
/g/:gid/projects                    → لو مشروع واحد: redirect لـ /g/:gid/p/:pid
/g/:gid/projects/new                [projects.manage]
/g/:gid/p/:pid                      → redirect حسب نوع المجموعة
/g/:gid/p/:pid/settings             [projects.manage]
/g/:gid/p/:pid/members              override الأدوار

── Software (group.type == software) ──
/g/:gid/p/:pid/board
/g/:gid/p/:pid/backlog
/g/:gid/p/:pid/sprints/:sid
/g/:gid/p/:pid/tasks/new            (قبل :tid)
/g/:gid/p/:pid/tasks/bulk           (قبل :tid)
/g/:gid/p/:pid/tasks/:tid
/g/:gid/p/:pid/tasks/:tid/edit
/g/:gid/p/:pid/reviews
/g/:gid/p/:pid/reviews/:prNumber

── Hardware (group.type == hardware) ──
/g/:gid/p/:pid/phases               خط المراحل EVT → DVT → PVT → MP
/g/:gid/p/:pid/phases/:phaseId      checklist + الـ builds + قرار الـ gate
/g/:gid/p/:pid/tasks/…              نفس مهام الـ Software بـ workflow مختلف
/g/:gid/p/:pid/parts
/g/:gid/p/:pid/parts/:partId
/g/:gid/p/:pid/bom                  الـ revision الحالية + المسودة
/g/:gid/p/:pid/bom/:rev
/g/:gid/p/:pid/eco
/g/:gid/p/:pid/eco/new
/g/:gid/p/:pid/eco/:ecoId           التغييرات + الاعتمادات بمرحلتين
/g/:gid/p/:pid/builds
/g/:gid/p/:pid/builds/:buildId      الوحدات + نتايج الاختبار
/g/:gid/p/:pid/units/:serial
/g/:gid/p/:pid/tests
/g/:gid/p/:pid/tests/:planId
/g/:gid/p/:pid/firmware             مصفوفة firmware ↔ HW revision
/g/:gid/p/:pid/purchasing           الاحتياج من الـ BOM × الكمية + أوامر الشراء
/g/:gid/p/:pid/purchasing/po/new
/g/:gid/p/:pid/purchasing/po/:poId
/g/:gid/p/:pid/links                [lead | admin] الربط مع مشاريع مجموعات تانية (استثنائي)

/account, /settings/…               حاجات المستخدم (مش مربوطة بمجموعة)
/notifications                      كل المجموعات، وكل إشعار فيه gid
```

**ليه `/g/:gid/p/:pid/...`؟**
- الرابط لوحده كفاية علشان الصفحة تتفتح (refresh في الويب، deep link، مشاركة رابط).
- المسارات الثابتة (`new` و `bulk`) **قبل** `:tid` علشان مشكلة `/tasks/bulk` ([02-routing.md](../review/02-routing.md)) ماتتكررش.
- كل route بيقرا الـ id من `state.pathParameters` بدل قيم وهمية زي `?? 58`.

### 6.2 الحراسة (guards)

كل route عليه **metadata** بالقدرة المطلوبة ونوع المجموعة، والـ `redirect` بيشيّك عليها:

```dart
// lib/routes/route_guards.dart
class RouteRule {
  const RouteRule({this.cap, this.groupType});
  final Capability? cap;
  final GroupType? groupType; // null = أي نوع
}

const routeRules = <String, RouteRule>{
  '/g/:gid/members/invite':  RouteRule(cap: Capability.manageMembers),
  '/g/:gid/settings':        RouteRule(cap: Capability.manageGroup),
  '/g/:gid/p/:pid/bom':      RouteRule(groupType: GroupType.hardware),
  '/g/:gid/p/:pid/eco/new':  RouteRule(cap: Capability.submitEco, groupType: GroupType.hardware),
  '/g/:gid/p/:pid/board':    RouteRule(groupType: GroupType.software),
  // ...
};

String? guard(Ref ref, GoRouterState state) {
  final gid = state.pathParameters['gid'];
  if (gid == null) return null;

  final access = ref.read(groupAccessProvider(gid));   // AsyncValue<GroupAccess>
  if (access.isLoading) return null;                    // الصفحة بتعرض skeleton
  final a = access.value;
  if (a == null) return '/groups?removed=$gid';         // مش عضو

  final rule = routeRules[state.fullPath];
  if (rule == null) return null;
  if (rule.groupType != null && rule.groupType != a.groupType) {
    return '/g/$gid/home';
  }
  if (rule.cap != null && !a.can(rule.cap!, projectId: state.pathParameters['pid'])) {
    return '/g/$gid/home?denied=1';
  }
  return null;
}
```

- `GoRouter(refreshListenable: …)` بيسمع لـ `authNotifierProvider` و `groupAccessProvider`، فلو الدور اتغير أو العضو اتشال الراوت بيتعاد تقييمه ([02-routing.md](../review/02-routing.md)).
- **الحراسة في التطبيق للتجربة بس.** الحماية الحقيقية هي `requireCap` في السيرفر على كل endpoint.
- الأزرار بتستخدم نفس `a.can(...)`: يا تختفي يا `onPressed: null`، بدل الأزرار الوهمية ([01-design.md](../review/01-design.md)).

### 6.3 الـ Providers

```dart
final activeGroupIdProvider = Provider<String?>(...);          // من الرابط
final myGroupsProvider = FutureProvider<List<GroupSummary>>(...); // GET /v1/groups
final groupAccessProvider =
    FutureProvider.family<GroupAccess, String>((ref, gid) => ...); // GET /v1/groups/:gid/me
// GroupAccess: groupType, groupRole, functionalRole, projectOverrides, caps
```

- كل الـ data providers تبقى `family` على `gid` (و `pid`)، فالتبديل بين المجموعات مش محتاج `reset()` يدوي ومفيش بيانات بتتسرّب بين مجموعتين.
- الـ `ApiClient` بيبعت `X-Workspace-Id` زي ما هو. والـ `gid` بيبقى **في مسار الـ API** (`/v1/groups/:gid/...`)، والسيرفر بيشيّك على العضوية في كل طلب.

---

## 7. إدارة مشاريع الهاردوير

### 7.1 المراحل والـ gates

**المراحل مش ثابتة.** القالب الافتراضي هو اللي تحت، والـ lead أو الـ admin يقدر من `/g/:gid/settings/phases`:

- يضيف مرحلة، أو يغيّر اسمها، أو يرتبها، أو يحذفها.
- يعدّل الـ checklist وشروط الخروج لكل مرحلة.
- يحدد مين يعتمد الـ gate.

**إزاي التعديل بيأثر على المشاريع؟**

- المجموعة فيها **قالب المراحل**، وكل مشروع جديد بياخد **نسخة** منه وقت إنشائه.
- **تعديل القالب** بيتطبق على المراحل اللي **لسه مابدأتش** في كل المشاريع. أما المراحل اللي بدأت أو اتعملها gate، فبتفضل زي ما هي لأنها سجل تاريخي.
- **مرحلة جديدة في القالب:** بتتضاف للمشاريع اللي لسه موصلتش لمكانها. والمشاريع اللي عدّت المكان ده بيظهر فيها اقتراح ("ضيف المرحلة دي؟").
- **حذف مرحلة** فيها builds أو gate اتعمله قرار مش مسموح. ينفع تتأرشف بس.

```
Concept → Proto → EVT → DVT → PVT → MP (إنتاج) → Sustaining   ← القالب الافتراضي
```

| المرحلة | الهدف | شرط الخروج (افتراضي، والتيم ليد يقدر يعدّله) |
|---|---|---|
| Proto | يثبت الفكرة (works-like / looks-like) | الوظيفة الأساسية شغالة |
| **EVT** | التحقق الهندسي | تصميم واحد على بُعد ≤ 3 iterations من الإنتاج |
| **DVT** | التحقق من التصميم | تصميم واحد يحقق كل المتطلبات (وظيفة، أداء، اعتمادية)، و pre-compliance (FCC/CE) |
| **PVT** | التحقق من الإنتاج | yield بسرعة الإنتاج على خط واحد على الأقل، وشهادات الاعتماد |
| MP | الإنتاج الكمي | ramp، وبعدها sustaining |

- **الـ gate:** checklist (deliverables) + معايير، والقرار **Go / Recycle / Hold / Kill**.
  - **Recycle** بيعمل build تاني في نفس المرحلة (EVT2). يعني لازم يبقى فيه **أكتر من build في المرحلة الواحدة**.
  - **Go** بيفتح المرحلة الجاية بتاريخ الـ gate الجاي.
- حالات الـ gate: `not_started → in_progress → ready_for_review → decided(go|recycle|hold|kill)`.
- كل مهمة Hardware عليها **tag بالمرحلة**.

### 7.2 الكيانات

| الكيان | أهم الحقول | MVP؟ |
|---|---|---|
| **Part** | رقم القطعة، revision، الوصف، الفئة، الحالة (`draft / prototype / production / obsolete`)، المورّد، MPN، التكلفة، المرفقات | ✅ |
| **BOM** | مستوى واحد في الـ MVP: part + كمية + reference designators. كل revision **snapshot ثابت** | ✅ (متعدد المستويات و where-used لاحقًا) |
| **ECO** (ومعاه الـ ECR) | القطع المتأثرة (rev قديم → جديد)، السبب، الأثر (تكلفة، مخزون، firmware)، الاعتمادات بمرحلتين | ✅ |
| **Design revision** | ملفات schematic و PCB و mechanical (rev A/B/C) مربوطة بـ ECO، والملفات المعتمدة (Gerbers، drawings) | ✅ (مرفقات) |
| **Build** | المرحلة (EVT1، DVT2…)، الـ BOM revision، الكمية، المصنّع (CM)، الحالة | ✅ |
| **Unit** | السيريال، الـ config، إصدار الـ firmware، المكان، الحالة | ✅ |
| **Test plan / result** | المتطلبات، معايير القبول، النتيجة pass/fail لكل وحدة | ✅ |
| **Firmware ↔ HW** | firmware release (من GitHub) ↔ الـ HW revisions المتوافقة | ✅ |
| **المشتريات والمخزن** | الموردين، أوامر الشراء، الأرصدة، الحجوزات، الـ lead times (القسم 7.5) | ✅ (المرحلة 4ب) |
| شهادات (FCC / CE / UL) بالمعمل والتواريخ | الشهادات بتاخد من 2 لـ 12 أسبوع والمعامل بتتحجز بدري | لاحقًا |
| حجز أجهزة المعمل | | لاحقًا |
| NCR / MRB / CAPA و RMA | | لاحقًا |
| تنبيهات الـ EOL | | لاحقًا |

**قاعدة رقم القطعة (Arena):** أي تغيير في form/fit/function = **رقم قطعة جديد**، والتغيير الصغير = **revision جديد**.

### 7.3 الـ Workflows

**كل الحالات اللي تحت افتراضية وقابلة للتعديل** من `/g/:gid/settings/workflow`، على مستوى المجموعة، ولكل مشاريعها (نفس طريقة Linear: الـ sub-teams بتورث الحالات من التيم الأب).

- كل حالة جوه **فئة ثابتة**: `backlog`، `active`، `blocked`، `done`، `cancelled`. الأسماء والعدد والترتيب بيتغيروا، بس الفئة هي اللي بيعتمد عليها الكود. التقارير و "مهامي" والـ burndown وملخص الـ sprint بيحسبوا بالفئة، مش بالاسم. وده كمان بيحل مشكلة "أي حاجة عندها نقاط تبقى مكتملة" ([01-design.md](../review/01-design.md)).
- **حذف حالة فيها مهام** لازم يحدد حالة بديلة تتنقل ليها المهام، والنقل بيتم جوه transaction.
- **الانتقالات** (مين يقدر ينقل من فين لفين) مفتوحة في الـ MVP. التقييد بالأدوار ييجي بعدين، مثلًا `test` بس اللي يقدر ينقل لـ Passed.
- **حالات الـ ECO الأساسية** (Submitted، Approved، Released) مقفولة علشان منطق الاعتماد، والـ lead يقدر يضيف حالات وسيطة بس.

**مهمة Hardware:**
```
Backlog → Design → Design Review → Ready for Fab → In Fab / Procurement
        → Assembly / Bring-up → Testing → Passed → Released
                                        ↘ Failed → Rework | ECR جديد
Blocked = flag مش عمود (مستني قطع / معمل / مورّد)
```

**ECO:**
```
Draft → Submitted → Design Review (مرحلة 1) → Production Review (مرحلة 2)
      → Approved → Implementing (تحديث BOM والملفات والمخزون) → Released (ECN) → Closed
جانبي: Rejected → (تعديل وإعادة تقديم | Cancelled) · On Hold
```
- الاعتماد بيتحدد من الـ approval matrix: الأدوار المطلوبة لكل مرحلة، و quorum (`any` أو `all`).
- **اللي قدّم الـ ECO مايقدرش يعتمده** (نفس قاعدة "مايعتمدش الـ PR بتاعه").
- لما ECO يتعمله Released: revision جديد للـ BOM (snapshot) + إشعار ECN لكل أعضاء المشروع.

**Build:**
```
Planned → Parts Ordered → At CM / Assembling → Received → Testing → Complete
```

### 7.4 الكوبري مع الـ Software (firmware)

- مشروع الـ firmware بيبقى جوه مجموعة الـ Hardware (أو مجموعة Software مربوطة بيها)، ومتوصل بـ GitHub بنفس الطريقة الحالية: tasks و PRs و reviews.
- **مصفوفة التوافق:** كل firmware release (tag في GitHub) ↔ HW revisions اللي اتختبر عليها.
- كل Unit بيتسجل عليه إصدار الـ firmware، فلما اختبار يفشل تعرف التركيبة بالظبط.

### 7.5 المشتريات والمخزن (Hardware بس)

أيوه، دي حاجة Hardware بس، ومش بتظهر في مجموعات الـ Software. بس **مش كلها على مستوى المشروع**، لأن نفس القطعة (مقاومة 10k، connector، MCU) بتتستخدم غالبًا في أكتر من مشروع جوه المجموعة. لو كل مشروع ليه مخزن، نفس الريل هيتسجل مرتين والأرصدة هتبقى غلط.

| على مستوى **المجموعة** (مشترك) | على مستوى **المشروع** |
|---|---|
| الموردين وبياناتهم | **الاحتياج:** BOM revision × كمية الـ build = القطع المطلوبة |
| رصيد المخزون الفعلي لكل رقم قطعة ومكانها | **أوامر الشراء** (PO): المشروع هو اللي بيطلب وبيدفع |
| حركات المخزون (استلام / صرف / تسوية) | **الحجز:** المشروع بيحجز كمية من الرصيد لـ build معين |
| | **التكلفة:** تكلفة الـ build من الأسعار الفعلية |

- **المتاح للحجز** = الرصيد − المحجوز لكل المشاريع. لو مشروعين محتاجين نفس القطعة وهي مش كفاية، الاتنين بيشوفوا العجز.
- **الاستلام:** PO بيتقفل جزئي أو كامل، وبيعمل حركة "استلام" للمخزن، والكمية بتتحجز تلقائي للمشروع اللي طلب.
- **صرف للـ build:** لما الـ build يبدأ التجميع، المحجوز بيتصرف ويتخصم من الرصيد.
- **تنبيه lead time:** لو تاريخ الـ build الجاي − الـ lead time بتاع القطعة < النهارده والكمية مش متاحة، بيظهر تنبيه "اطلب دلوقتي".
- لو المجموعة فيها مشروع واحد، الفرق بين المستويين مش بيبان، وكأن المخزن بتاع المشروع.

**الأدوار:**

| القدرة | lead | admin | procurement | electrical / mechanical | technician | client |
|---|---|---|---|---|---|---|
| إدارة الموردين | ✓ | ✓ | ✓ | R | – | – |
| إنشاء PO | ✓ | ✓ | ✓ | طلب شراء بس | – | – |
| اعتماد PO (فوق حد مبلغ) | ✓ | ✓ | – | – | – | – |
| استلام / صرف / تسوية مخزن | ✓ | ✓ | ✓ | – | ✓ (استلام وصرف) | – |
| رؤية الأسعار | ✓ | ✓ | ✓ | ✓ | – | – |

**حالات الـ PO** (افتراضية وقابلة للإضافة):
```
Draft → Pending Approval → Ordered → Partially Received → Received → Closed
جانبي: Cancelled
```

---

## 8. نموذج البيانات (migration `0002_groups.sql`)

> **ما تعدّلش `0001`.** كل ده في ملف جديد ([05-future-risks.md](../review/05-future-risks.md)).

```sql
create table groups (
  id           text primary key,
  workspace_id text not null references workspaces (id) on delete cascade,
  name         text not null check (length(name) between 1 and 80),
  type         text not null check (type in ('software', 'hardware')),
  template     text not null default 'scrum',
  settings     text not null default '{}',   -- approval matrix، شروط الـ gates
  is_archived  integer not null default 0,
  created_by   text references users (uid) on delete set null,
  created_at   text not null,
  updated_at   text not null
);
create index groups_workspace_idx on groups (workspace_id);

create table group_members (
  group_id        text not null references groups (id) on delete cascade,
  user_uid        text not null references users (uid) on delete cascade,
  group_role      text not null check (group_role in ('lead', 'admin', 'member', 'guest')),
  functional_role text not null,             -- بيتشيّك في الـ API حسب نوع المجموعة
  created_at      text not null,
  primary key (group_id, user_uid)
);
create unique index group_members_single_lead_idx
  on group_members (group_id) where group_role = 'lead';
create index group_members_user_idx on group_members (user_uid);

-- الدعوة بتبقى لمجموعة (group_id + الأدوار). ونشيل 'owner' من الـ CHECK.
alter table workspace_invites add column group_id text references groups (id) on delete cascade;
alter table workspace_invites add column group_role text;
alter table workspace_invites add column functional_role text;

alter table projects add column group_id text references groups (id) on delete cascade;
alter table projects add column visibility text not null default 'group'
  check (visibility in ('group', 'private'));
create index projects_group_idx on projects (group_id);

create table project_members (                -- override
  project_id      text not null references projects (id) on delete cascade,
  user_uid        text not null references users (uid) on delete cascade,
  functional_role text not null,
  access          text not null check (access in ('edit', 'read')),
  primary key (project_id, user_uid)
);
```

**الحالات والمراحل القابلة للتعديل (في نفس `0002`):**

```sql
create table workflow_states (               -- حالات المهام / الـ ECO / الـ build / الـ PO
  id         text primary key,
  group_id   text not null references groups (id) on delete cascade,
  entity     text not null check (entity in ('task', 'eco', 'build', 'po')),
  name       text not null check (length(name) between 1 and 40),
  category   text not null check (category in ('backlog', 'active', 'blocked', 'done', 'cancelled')),
  color      text not null,                   -- '#RRGGBB' والتطبيق بيعمله parse (درس لون الـ labels)
  ord        integer not null,
  is_locked  integer not null default 0,      -- حالات الـ ECO الأساسية
  archived   integer not null default 0
);
create index workflow_states_group_idx on workflow_states (group_id, entity, ord);
-- tasks.status بيبقى state_id يشاور على workflow_states بدل نص ثابت

create table phase_templates (               -- [hardware] قالب المراحل على مستوى المجموعة
  id         text primary key,
  group_id   text not null references groups (id) on delete cascade,
  name       text not null,                   -- EVT، DVT، أو أي اسم
  ord        integer not null,
  checklist  text not null default '[]',      -- json: deliverables + شروط الخروج
  approvers  text not null default '[]',      -- json: الأدوار + quorum
  archived   integer not null default 0
);
```

**جداول الهاردوير (`0003_hardware.sql`):**

```sql
create table hw_phases   (id, project_id, template_id /*phase_templates*/, name, ord, status,
                          gate_decision, gate_decided_by, gate_decided_at, checklist /*json, نسخة*/);
create table hw_parts    (id, project_id, part_number, revision, description, category,
                          lifecycle, mpn, vendor, unit_cost_cents, unique (project_id, part_number, revision));
create table hw_bom_revs (id, project_id, rev, status /*draft|released*/, released_by, released_at,
                          eco_id);
create table hw_bom_lines(bom_rev_id, part_id, quantity, ref_designators);
create table hw_ecos     (id, project_id, number, title, reason, impact /*json*/, status,
                          submitted_by, created_at, updated_at);
create table hw_eco_items(eco_id, part_id, from_rev, to_rev, action /*add|change|remove*/);
create table hw_eco_approvals(eco_id, stage /*design|production*/, user_uid, decision, comment, at);
create table hw_builds   (id, project_id, phase_id, name /*EVT1*/, bom_rev_id, quantity, cm, status);
create table hw_units    (id, build_id, serial, firmware_version, location, status,
                          unique (build_id, serial));
create table hw_test_plans  (id, project_id, phase_id, title, criteria /*json*/, approved_by);
create table hw_test_results(id, plan_id, unit_id, result /*pass|fail*/, notes, recorded_by, at);
create table hw_fw_compat   (project_id, firmware_tag, bom_rev_id, verified_by, at);
```

**المشتريات والمخزن (`0004_inventory.sql`):**

```sql
-- على مستوى المجموعة
create table inv_vendors   (id, group_id, name, contact /*json*/, default_lead_days);
create table inv_stock     (group_id, part_number, location, on_hand, primary key (group_id, part_number, location));
create table inv_movements (id, group_id, part_number, location, qty /*+ أو -*/,
                            kind /*receive|issue|adjust|transfer*/, project_id, build_id, po_id,
                            by_uid, at, note);
-- on_hand = مجموع الحركات. الحركات append-only ومش بتتعدّل، والتصحيح بحركة adjust جديدة.

-- على مستوى المشروع
create table inv_reservations (id, project_id, build_id, part_number, qty, status /*active|issued|released*/);
create table inv_pos       (id, project_id, vendor_id, number, state_id /*workflow_states po*/,
                            total_cents, currency, approved_by, ordered_at, expected_at);
create table inv_po_lines  (po_id, part_number, qty, unit_cost_cents, received_qty);
```

- كل الكميات والتعديلات على الرصيد بتتعمل **جوه transaction**. الحجز بيشيّك على `المتاح = on_hand − sum(active reservations)` وبيكتب في نفس الـ transaction، علشان طلبين مايحجزوش نفس الكمية.
- الفلوس بتتخزن **integer cents**، مش float.

كل جداول `hw_*` **لازم** الـ queries بتاعتها تشيّك على `project_id ∈ مشاريع المجموعة ∈ الـ workspace`. ده نفس درس `project_id` في [04-backend.md](../review/04-backend.md).

---

## 9. الـ API

```
GET    /v1/groups                          مجموعاتي (+ دوري + النوع)
POST   /v1/groups                          [workspace member]  → اللي عملها بيبقى lead
GET    /v1/groups/:gid/me                  → GroupAccess (الأدوار + الـ caps)
PATCH  /v1/groups/:gid                     [lead | admin]
DELETE /v1/groups/:gid                     [lead]
POST   /v1/groups/:gid/transfer            [lead]
GET    /v1/groups/:gid/members             (guest: من غير إيميلات)
PATCH  /v1/groups/:gid/members/:uid        [members.manage]  (admin مايرقّيش لـ admin)
DELETE /v1/groups/:gid/members/:uid        [members.manage]
POST   /v1/groups/:gid/invites             [members.manage]  (حد أقصى 50 / validation)
DELETE /v1/invites/:id                     [members.manage]  إلغاء
GET    /v1/invites/:id                     للمدعو بس (الإيميل لازم يطابق إيميل مُوثّق)
POST   /v1/invites/:id/accept | /decline
GET    /v1/groups/:gid/projects
POST   /v1/groups/:gid/projects            [projects.manage]
PUT    /v1/projects/:pid/members/:uid      override

# Hardware
GET|POST         /v1/projects/:pid/phases | parts | bom | ecos | builds | tests
POST             /v1/ecos/:id/submit | approve | reject
POST             /v1/bom/:rev/release           [bom.release]
POST             /v1/phases/:id/gate            [gate.decide]
POST             /v1/units/:id/results          [tests.record]

# الحالات والمراحل (على مستوى المجموعة)
GET|POST|PATCH   /v1/groups/:gid/workflow-states        [lead | admin للتعديل]
DELETE           /v1/workflow-states/:id?move_to=<id>   لازم حالة بديلة لو فيها عناصر
GET|POST|PATCH   /v1/groups/:gid/phase-templates        [hardware, lead | admin]

# المشتريات والمخزن [hardware]
GET|POST         /v1/groups/:gid/vendors
GET              /v1/groups/:gid/stock?part=…
POST             /v1/groups/:gid/stock/movements         [inventory.move]
GET              /v1/projects/:pid/demand               الاحتياج من الـ BOM × الـ builds
GET|POST         /v1/projects/:pid/pos
POST             /v1/pos/:id/approve | receive          [po.approve] | [inventory.move]
POST             /v1/projects/:pid/reservations         [builds.manage]

# الخطة والربط
GET              /v1/workspace/plan                     { plan, max_groups, used_groups }
POST             /v1/projects/:pid/links                [lead | admin] طلب ربط (لاحقًا)
POST             /v1/links/:id/approve | revoke          [lead | admin للطرف التاني]
```

- كل endpoint عليه `requireCap`، وكل query بيشيّك على الـ workspace والمجموعة.
- الـ snapshot الحالي بيتقسم: `/v1/groups/:gid/summary` للعدادات، وكل قائمة بـ pagination ([05-future-risks.md](../review/05-future-risks.md)).
- الأخطاء بترجع **كود** (`not_group_member`، `missing_capability`، `group_type_mismatch`)، والتطبيق هو اللي يترجمها.

---

## 10. نقل البيانات الحالية

1. لكل workspace بنعمل مجموعة واحدة: `type = software`، والاسم بنفس اسم الـ workspace.
2. كل `workspace_members` بتتنقل لـ `group_members`:

   | الدور القديم | `group_role` | `functional_role` |
   |---|---|---|
   | owner | lead | tech_lead |
   | admin | admin | tech_lead |
   | developer | member | developer |
   | reviewer | member | reviewer |
   | viewer | guest | client |

3. كل `projects.group_id` = المجموعة الجديدة.
4. الدعوات المعلّقة بتاخد `group_id` المجموعة الافتراضية.
5. الـ endpoints القديمة (`/v1/projects`، `/v1/tasks`…) بتفضل شغالة على المجموعة الافتراضية لفترة انتقالية، لحد ما التطبيق يتنقل على `/g/:gid`.

---

## 11. خطة التنفيذ

| المرحلة | المحتوى | يعتمد على |
|---|---|---|
| **0** | إصلاحات الحماية 🔴 من [docs/review](../review/README.md)، خصوصًا بنود 1 و 3 و 13 و 16، والـ redirect بـ `refreshListenable` | — |
| **1** ✅ | `groups` و `group_members` والـ migration، و `requireCap`، و `GET /v1/groups/:gid/me`، و**حدود الخطة** (10 / 50) | 0 |
| **2** ✅ | الراوت الجديد `/g/:gid/...` والـ guards، و `/groups` والـ switcher والعداد، والدعوة بـ `/invite/:id` والـ welcome، والـ redirect لو المجموعة فيها مشروع واحد. نقل شاشات الـ Software الحالية تحت `/g/:gid/p/:pid` | 1 |
| **3** ✅ | **الحالات القابلة للتعديل** (`workflow_states` بالفئات) وشاشة `/settings/workflow`، والشاشة الرئيسية حسب الدور، والـ override على مستوى المشروع، والمشاريع الخاصة | 2 |
| **4أ** ✅ | Hardware MVP: **قالب المراحل القابل للتعديل** والـ gates، والـ parts، والـ BOM بمستوى واحد، والـ ECO باعتماد مرحلتين، والـ builds والوحدات، والاختبارات، و firmware ↔ HW | 3 |
| **4ب** ✅ | **المشتريات والمخزن:** الموردين والمخزن المشترك على مستوى المجموعة، والاحتياج والـ PO والحجز على مستوى المشروع، وتنبيهات الـ lead time | 4أ |
| **5** | لاحقًا: **ربط المشاريع بين المجموعات (استثنائي)**، و BOM متعدد المستويات و where-used، والشهادات، وحجز المعمل، و NCR/MRB/RMA، و custom roles، وشاشة الـ approval matrix، وتقييد الانتقالات بين الحالات بالأدوار، وتكامل Altium / KiCad / Onshape، وشاشة "ليه الشخص ده يقدر يعمل كذا" | 4ب |

---

## 11.1 المرحلة 1: اللي اتنفذ

**الـ migration (`0003_groups.sql`):**
- جداول `plans` (العادية: 10 مجموعات، المدفوعة: 50 مجموعة بـ 6000 سنت) و `groups` و `group_members` (قائد واحد بس لكل مجموعة، والقاعدة نفسها بتضمن ده) و `project_members`.
- عمود `group_id` اتضاف للمشاريع وللدعوات.
- كل workspace موجود اتعمله مجموعة افتراضية (`is_default`) نوعها software، وانتقل ليها كل أعضائه ومشاريعه ودعواته المعلّقة، بالـ mapping اللي في القسم 10.

**القدرات (`caps.go`):**
- كل endpoint بيطلب قدرة (capability) مش دور.
- الـ lead واخد كل القدرات.
- الـ admin بيدير المجموعة، بس القدرات التشغيلية بياخدها من دوره الوظيفي بس.
- الـ guest للقراءة بس، وممكن يسجّل قرار العميل.
- المجموعة المأرشفة للقراءة بس.
- owner و admin الـ workspace يقدروا يديروا أي مجموعة حتى لو مش أعضاء فيها، علشان مفيش مجموعة تفضل من غير حد يديرها. بس مابياخدوش أي قدرات تشغيلية.

**الـ API:**

```
GET    /v1/workspace/plan                     الخطة + used / max
GET    /v1/groups                             مجموعاتي (والكل لأدمن الـ workspace) + الخطة
POST   /v1/groups                             {name, type, template?, description?} → 409 group_limit_reached
GET    /v1/groups/{gid}/me                    group_role + functional_role + capabilities
PATCH  /v1/groups/{gid}                       {name?, description?, is_archived?}
DELETE /v1/groups/{gid}                       للـ lead، ولمجموعة فاضية بس (غير كده: أرشفة)
POST   /v1/groups/{gid}/transfer              {uid} → الـ lead القديم بيبقى admin
GET    /v1/groups/{gid}/members               الضيف مابيشوفش الإيميلات
PATCH  /v1/groups/{gid}/members/{uid}         {group_role?, functional_role?}
DELETE /v1/groups/{gid}/members/{uid}         إزالة، أو مغادرة لو uid = نفسك
POST   /v1/groups/{gid}/invites               {emails, group_role?, functional_role?}
POST   /v1/projects                           {..., group_id?} → لازم projects.manage في المجموعة
```

**القواعد:**
- الـ admin مايقدرش يعيّن admin تاني، ولا ينزّله، ولا يشيله.
- القيادة بتتنقل من «نقل القيادة» بس، والـ lead مايقدرش يمشي قبل ما ينقلها.
- الدور الوظيفي لازم يكون متاح لنوع المجموعة.
- دور `client` بييجي مع `guest` بس.
- مينفعش تشيل عضو من الـ workspace لو هو قائد مجموعة.
- المجموعات المأرشفة مش بتتحسب في حد الخطة، بس فك الأرشفة محتاج يكون فيه مكان فاضي.
- الحد بيتشيّك جوه نفس الـ transaction اللي بتعمل المجموعة، وقاعدة البيانات باتصال واحد، فطلبين في نفس اللحظة مايقدروش ياخدوا آخر مكان مع بعض.
- الـ endpoints القديمة (`/v1/invites` و `/v1/projects` من غير `group_id`) بتشتغل على المجموعة الافتراضية.

**الاختبارات:** `groups_integration_test.go` فيه 7 سيناريوهات، و `internal/db/migrate_test.go` بيختبر الـ migration على بيانات قديمة.

## 11.2 المرحلة 2: اللي اتنفذ (2أ)

**الـ backend:**
- الـ endpoints القديمة (`/v1/projects` و `/v1/tasks` والـ snapshot) بقت بتعرض **المجموعة الافتراضية بس**. أي مجموعة تانية بتتقري بـ `?group_id=` بعد ما يتأكد إن المستخدم عضو فيها. قبل كده أي عضو في الـ workspace كان بيشوف مشاريع كل المجموعات.
- إنشاء المهمة أو تغيير حالتها أو حذفها في مجموعة غير الافتراضية محتاج `tasks.edit` في المجموعة دي. ولو المستخدم مش عضو بيرجعله `404`، علشان مايعرفش إن المهمة موجودة أصلًا.
- `GET /v1/invites/{id}` بيرجّع الدعوة لصاحب الإيميل بس، وأي حساب تاني بيشوف الإيميل متغطي (`s***@company.com`). و `POST /v1/invites/{id}/decline` لرفض الدعوة.
- `/me` بقى بيرجّع الـ `uid` المتخزن للمستخدم، علشان التطبيق يعرف مين هو جوه قائمة الأعضاء.

**التطبيق (`lib/features/groups/`):**

| المسار | الشاشة |
|---|---|
| `/groups` | مجموعاتي + عداد الخطة + الدعوات المعلّقة + المؤرشفة |
| `/groups/new` | إنشاء مجموعة: الاسم، والنوع (مش بيتغير بعدين)، والقالب |
| `/g/:gid` | بيحوّلك لـ `/g/:gid/home` |
| `/g/:gid/home` | الرئيسية حسب الدور: «أول حاجة ليك»، والمشاريع، والأعضاء، والإعدادات |
| `/g/:gid/p/:pid` | مهام المشروع: إضافة ونقل بين الحالات (لو دورك بيسمح) |
| `/g/:gid/members` | الأعضاء: تعديل الدور وإزالة العضو (`members.manage`)، والمغادرة |
| `/g/:gid/members/invite` | دعوة لحد 50 إيميل بدور إداري ووظيفي محددين مسبقًا |
| `/g/:gid/settings` | الاسم، والأرشفة، ونقل القيادة، والحذف (`group.manage`) |
| `/g/:gid/welcome` | أول شاشة بعد قبول الدعوة |
| `/invite/:inviteId` | قبول أو رفض الدعوة، وحالات: انتهت، مش لحسابك، انت عضو بالفعل |

- **`GroupScope`:** كل شاشة مجموعة جواه. بيحمّل `groupAccessProvider(gid)`، ولو المستخدم مش عضو بيعرض «مش قادر تفتح المجموعة»، ولو ماعندوش القدرة المطلوبة بيعرض «الصفحة دي مش متاحة لدورك». والأزرار بتتقفل أو تختفي حسب `access.can(...)`. ده الجزء الخاص بالتجربة بس، والسيرفر هو اللي بيحمي فعليًا.
- **تبديل المجموعات:** من زرار في الـ AppBar (في المشاريع وفي رئيسية المجموعة). بيعرض نوع كل مجموعة ودورك فيها والعداد.
- **`?from=` في تسجيل الدخول:** لو فتحت `/invite/:id` وانت مش مسجّل، بيوديك على `/login?from=/invite/:id`، وبعد الدخول بيرجّعك للدعوة. وبيرفض أي `from` مش مسار جوه التطبيق (`//host` أو `https://...`).
- **شاشة البداية:** بتفتح آخر مجموعة فتحتها. واتصلح كمان الـ spinner اللي كان بيعلّق ([02-routing.md](../review/02-routing.md)).
- **إشعار الدعوة:** بيفتح `/invite/:id` بتاع الدعوة دي بالظبط، مش «أحدث دعوة».

### المرحلة 2ب: الشاشات الكاملة لكل مجموعة Software

**القرار:** بدل ما الـ 86 مسار يتكتبوا تاني تحت `/g/:gid/p/:pid`، الشاشات الكاملة الموجودة (الـ board والـ sprints والمراجعات والمهام والأعضاء) بقت شغالة على **المجموعة النشطة**:

- التطبيق بيبعت `X-Group-Id` مع كل طلب، زي `X-Workspace-Id` بالظبط (`activeGroupProvider` في `lib/features/groups/presentation/providers/active_group.dart`).
- السيرفر بيتأكد إنك عضو في المجموعة، وبعدين بيقصر عليها الـ snapshot و `/v1/projects` و `/v1/tasks`.
- **الـ snapshot بيعرض المجموعة دي بس:** المهام، والتعليقات، والمهام الفرعية، والاعتماديات، والنشاط، والـ sprints، والـ PRs، والـ labels، والـ repositories. وكمان أعضاء المجموعة بأدوارهم، معروضين بأسماء الأدوار القديمة اللي الشاشات فاهماها: lead = owner، و guest = viewer.
- المشروع اللي بيتعمل من الشاشات القديمة بيروح للمجموعة النشطة.
- لما تفتح رئيسية مجموعة، بتبقى هي المجموعة النشطة. تبديل المجموعة بيعيد تحميل الـ snapshot والمهام والمشاريع لوحدهم، لأنهم بيعملوا `watch` على المجموعة النشطة.
- **لو اتشلت من المجموعة النشطة:** السيرفر بيرجّع `not_group_member`، والتطبيق بيرجع للمجموعة الافتراضية على طول.
- **عند الخروج:** المجموعة النشطة بتتمسح.
- اسم المجموعة النشطة بيظهر تحت عنوان «المشاريع».
- تقرير العميل لسه في المجموعة الافتراضية بس.

**حراسة الشاشات القديمة حسب الدور** (`ActiveGroupGuard`)، بقدرات المجموعة النشطة:

| الشاشة | القدرة المطلوبة |
|---|---|
| إعدادات المشروع، الفواتير، تصدير البيانات | `group.manage` |
| ربط repository، المزامنة، الـ labels، التكاملات، الأرشيف | `projects.manage` |
| الأعضاء، الدعوة، الدعوة الجماعية | `members.manage` |

**ليه مش `/g/:gid/p/:pid/...` لكل شاشة؟** إعادة كتابة 86 مسار كانت هتعيد كل مشاكل الراوت اللي في [02-routing.md](../review/02-routing.md). المجموعة النشطة بتدّي نفس النتيجة من غير ده: كل مجموعة Software ليها كل الشاشات، والحماية في السيرفر. وروابط المجموعة نفسها (`/g/:gid/...`) فاضلة زي ما هي للشاشات الجديدة. ولما شاشات الـ Hardware تتعمل في المرحلة 4، هتبقى تحت `/g/:gid/p/:pid/...` من الأول.

## 11.3 المرحلة 3: اللي اتنفذ

### الحالات القابلة للتعديل

**الـ migration:** `0004_workflow.sql`.

- **جدول `workflow_states`** لكل مجموعة. كل حالة ليها اسم (1–40 حرف) ولون `#RRGGBB` وترتيب وفئة: `backlog`، `active`، `blocked`، `done`، `cancelled`. الفئة هي اللي بتتحسب في التقارير والرئيسية، والاسم واللون حرّين.
- **الحالات الافتراضية:** كل مجموعة بتبدأ بـ «للتنفيذ» و«جاري» و«مراجعة» و«تم». مجموعة الـ Hardware بتاخد كمان «متوقف». الـ trigger بيعملهم لوحده مع أي مجموعة جديدة، والـ migration عملتهم للمجموعات الموجودة.
- **`tasks.state_id`** جنب `tasks.status` القديم. كل حالة شايلة `legacy_status`، يعني إزاي الـ board القديم بيعرضها. الفئة بتتحول كده: backlog = todo، و active و blocked = in_progress، و done و cancelled = done. «مراجعة» الافتراضية بتفضل review.
- **triggers بتربط الاتنين ببعض:**
  - الكود الجديد بيبعت `state_id`، والسيرفر بيحط `status` المناسب ليه.
  - الكود القديم (الـ board، و webhook الـ GitHub) بيبعت `status` بس، والـ trigger بيختار أول حالة في المجموعة بنفس الـ status.
  - لو مفيش حالة بنفس الـ status، بيختار أول حالة من نفس الفئة.
  - المهمة اللي اتنقلت لمشروع في مجموعة تانية بتاخد حالة من المجموعة الجديدة.
- **القواعد** (السيرفر بيطبقها، والشاشة بتشرحها قبل ما الطلب يتبعت):
  - الحد الأقصى 20 حالة شغالة في المجموعة.
  - مفيش اسمين زي بعض.
  - الحالة اللي فيها مهام مش بتتأرشف. انقل المهام الأول.
  - لازم يفضل في المجموعة حالة واحدة على الأقل من فئة backlog (المهام الجديدة بتنزل فيها)، وواحدة من فئة done.
  - **كل عمود في الـ board القديم** (todo / in_progress / review / done) لازم يفضل ليه حالة شغالة. يعني «مراجعة» الافتراضية تتغير اسمها أو لونها، بس ماتتأرشفش ولا تتغير فئتها، طول ما هي الوحيدة. ليه؟ الكود القديم بيبعت `status` بس، ولو مفيش حالة ليه الـ trigger هيحط المهمة في حالة بتتعرض في عمود تاني، والاتنين هيفضلوا مش متطابقين. القيد ده بيتشال لما الـ board يقرا `state_id`.
  - الاسترجاع من الأرشيف بيتشيّك على تكرار الاسم كمان.
  - لو غيّرت فئة حالة، المهام اللي فيها بتتعرض تحت الـ status الجديد في الـ board القديم.
  - الحالات الـ locked (للـ ECO في المرحلة 4) فئتها مش بتتغير ومش بتتأرشف.

**الـ API:**

| الطلب | مين يقدر |
|---|---|
| `GET /v1/groups/{gid}/workflow` | كل الأعضاء |
| `POST /v1/groups/{gid}/workflow` | `workflow.manage` |
| `PATCH /v1/groups/{gid}/workflow/{sid}` | `workflow.manage` |
| `PUT /v1/groups/{gid}/workflow/order` | `workflow.manage` |
| `PATCH /v1/tasks/{id}/status` بـ `state_id` أو `status` | `tasks.edit` |

والـ snapshot بقى بيرجّع `workflow_states` بتاعة المجموعة النشطة، وكل مهمة فيها `state_id`.

**الشاشات:**
- `/g/:gid/settings/workflow`: إضافة، وتعديل الاسم والفئة واللون، والترتيب بالسحب، والأرشفة والاسترجاع.
- شاشة المشروع `/g/:gid/p/:pid` بقت بتقسّم المهام على حالات المجموعة بألوانها. النقل بيبقى لأي حالة.

**لسه:** الـ board الكامل القديم بيعرض الأعمدة الأربعة الثابتة. الحالات الجديدة بتظهر تحت الـ status بتاعها. عرض أعمدة حسب حالات المجموعة في الـ board ده جاي بعدين.

### الرئيسية حسب الدور

**`GET /v1/groups/{gid}/home`.** السيرفر هو اللي بيقرر كل دور يشوف إيه:

| الدور | بيشوف |
|---|---|
| الكل | عدد المهام في كل فئة، وتقدم كل مشروع |
| العضو (مش ضيف) | مهامه المفتوحة (أقرب ميعاد الأول، وبعدين الأولوية)، وعدد المتأخر منها |
| القائد والمساعدين | الفريق: عدد الأعضاء، والدعوات اللي لسه ماتقبلتش، والمهام المتوقفة، والمهام من غير مسؤول، والمتأخرة |
| الضيف (العميل) | التقدم بس، من غير أسماء ولا مهام |

قائمة «أول حاجة ليك» الثابتة اتشالت واتحط مكانها الأرقام دي.

### المشاريع الخاصة والـ override على مستوى المشروع

- **`projects.visibility = 'private'`:** المشروع بيظهر لقائد المجموعة والمساعدين وأعضاء المشروع (`project_members`) بس.
  - الفلتر ده بيتطبق في كل مكان: قائمة المشاريع، والمهام، والـ snapshot (المهام والتعليقات والمهام الفرعية والاعتماديات والنشاط والـ sprints والـ PRs والـ labels والـ repositories)، والرئيسية.
  - لو حد مش من دول حاول يعدّل مهمة في المشروع، بياخد `404`، علشان مايعرفش إن المشروع موجود أصلًا.
- **`project_members`:**
  - `access = read`: العضو بيشوف المشروع بس، ومايقدرش يعدّل فيه.
  - `access = edit`: العضو بيعدّل المهام في المشروع ده.
  - `functional_role` (اختياري): دور تاني في المشروع ده بس، زي مبرمج بيراجع في مشروع واحد.
  - الضيف: قراءة بس، ودوره ثابت.
  - القائد: مالوش override، صلاحياته كاملة في كل المشاريع.
  - لازم الشخص يكون عضو في المجموعة الأول. المشروع مش بيدخّل حد من برة المجموعة.
  - **الظهور والـ overrides للقائد والمساعدين بس** (`group.manage`)، مش لأي حد معاه `projects.manage`. قائد تقني عنده override على مشروع خاص مايقدرش يفتحه للمجموعة كلها، ولا يضيف حد للمشروع.
- **لما حد يخرج من المجموعة أو من مساحة العمل،** الـ overrides بتاعته بتتمسح. ده بيمنع إنه يرجع لمشروع خاص بصف قديم لو اتضاف تاني.

**الـ API:**

| الطلب | مين يقدر |
|---|---|
| `GET /v1/groups/{gid}/projects/{pid}/me` | اللي يشوف المشروع |
| `PATCH /v1/groups/{gid}/projects/{pid}` (الاسم والوصف) | `projects.manage` |
| `PATCH /v1/groups/{gid}/projects/{pid}` (الظهور) | `group.manage` |
| `GET /v1/groups/{gid}/projects/{pid}/members` | `group.manage` |
| `PUT /v1/groups/{gid}/projects/{pid}/members/{uid}` | `group.manage` |
| `DELETE /v1/groups/{gid}/projects/{pid}/members/{uid}` | `group.manage` |

**الشاشة:** `/g/:gid/p/:pid/settings`. فيها مفتاح «مشروع خاص»، وقائمة الـ overrides، وإضافة عضو بصلاحية قراءة أو تعديل وبدور خاص.

### ثغرات قديمة اتقفلت في نفس المرحلة

- **`POST /v1/projects/{id}/archive`:** كان أي عضو في مساحة العمل يقدر يأرشف مشروع في أي مجموعة. دلوقتي محتاج `projects.manage` في مجموعة المشروع.
- **`POST /v1/pull-requests/{number}/review`:** الـ PR بيتحدد برقمه في مساحة العمل كلها، فأي عضو كان يقدر يعتمد أو يرفض PR في مجموعة مش بتاعته. دلوقتي المراجعة بتتقصر على المجموعة النشطة، وبتمشي بصلاحياتك على مشروع الـ PR: صلاحية القراءة بس مش بتعتمد، والدور الخاص بالمشروع ممكن يدّي `pr.review`.
- **مراجعة مستقلة للمرحلة** لقت تسريبات اتقفلت قبل الـ commit: مهام المشروع الخاص كانت بتظهر جوه عناصر sprint ظاهر، ومفتاح المهمة الخاصة كان بيظهر في PR مربوط بيها، وعدد المهام المفتوحة لكل عضو كان بيحسب المشاريع الخاصة.

## 11.4 المرحلة 4أ: اللي اتنفذ (Hardware MVP)

**الـ branch:** `v10.0`. **الـ migration:** `0005_hardware.sql`.

**القاعدة الأساسية:** كل الـ endpoints تحت `/v1/groups/{gid}/projects/{pid}/hw/...` وبتعدّي على `hwHandler`. الـ handler ده بيعمل تلات حاجات:
- بيتأكد إن المجموعة Hardware. لو مش كده بيرجّع `409 group_type_mismatch`.
- بيحسب صلاحياتك على **المشروع**: المشروع الخاص بيرجّع `404`، و«قراءة بس» بتشيل صلاحيات الكتابة.
- كل عنصر جوه المشروع (BOM، قطعة، ECO، build، وحدة، خطة اختبار، مرحلة) بيتدوّر عليه **مع** رقم المشروع. يعني رقم عنصر من مشروع تاني بيرجّع `404`.

### المراحل والـ gates

- **قالب المراحل على مستوى المجموعة** (`phase_templates`): Proto، EVT، DVT، PVT، MP، ولكل مرحلة checklist. مجموعة Hardware جديدة بتاخده من trigger، والمجموعات الموجودة اتعملها من الـ migration.
- **المشروع الجديد بياخد نسخة من القالب** (trigger). أول مرحلة بتبدأ على طول.
- **تعديل القالب** (`/g/:gid/settings/phases`، ومحتاج `workflow.manage`):
  - **تغيير الاسم أو الـ checklist** بيوصل للمراحل اللي **لسه مابدأتش** بس. المرحلة اللي بدأت أو اتعملها gate سجل تاريخي ومش بتتغير.
  - **مرحلة جديدة** بتتضاف في آخر كل مشروع، إلا المشروع اللي اتعمله kill.
  - **الأرشفة** بتشيل النسخ اللي لسه مابدأتش، لو مفيش حاجة مربوطة بيها (builds أو خطط اختبار أو gate).
  - **الاسترجاع** بيرجّعها في الآخر.
  - **الترتيب** بيتطبق على المراحل اللي لسه مابدأتش.
- **حالات المرحلة:** `not_started` ← `in_progress` ← `ready_for_review` ← قرار الـ gate. وكمان `on_hold` و `passed` و `killed`.
- **قرار الـ gate** (`gate.decide`):
  - **Go:** المرحلة بتعدّي، والمرحلة اللي بعدها بتبدأ.
  - **Recycle:** جولة تانية في نفس المرحلة (EVT2). الشاشة بتعرض رقم الجولة.
  - **Hold:** وقف مؤقت.
  - **Kill:** المرحلة دي وكل اللي بعدها بيتقفلوا.
  - كل قرار بيتسجل في `hw_gate_decisions` بالملاحظة واسم اللي أخده.
- **الـ checklist:** أي حد معاه `tasks.edit` أو `builds.manage` أو `gate.decide` يقدر يعلّم على بنودها، **بعد ما المرحلة تبدأ**. قبل كده هي لسه تبع القالب، وأي تعديل في القالب كان هيمسح العلامات.
- **Go** بيبدأ أول مرحلة لسه مابدأتش حسب ترتيب القالب. يعني بعد إعادة الترتيب مفيش مرحلة بتتنط.

### القطع والـ BOM

- **`hw_parts`:** رقم القطعة + الـ revision لازم يكونوا فريدين في المشروع، والـ revision بيتحول لحروف كبيرة. رقم القطعة والـ revision مش بيتعدّلوا: الـ revision الجديد بيبقى قطعة جديدة (قاعدة Arena).
- **الأسعار** (`unit_cost_cents`، بالسنت كأرقام صحيحة) مش بتظهر للي معاهوش `prices.view`. ده بيشمل الفني والعميل، وبيشمل الحقل نفسه وإجمالي تكلفة الـ BOM. والفني مايقدرش يحدد سعر.
- **الـ BOM:**
  - الـ revisions بتتسمى A و B و C… ولو عدّت Z بتبقى AA.
  - **مفيش غير draft واحد** في المرة.
  - الـ draft الجديد بيتنسخ من آخر release.
  - الـ release محتاج `bom.release` وقطعة واحدة على الأقل.
  - **الـ revision اللي اتعمله release ثابت:** triggers في قاعدة البيانات بترفض أي تعديل على سطوره، حتى لو الطلب جه من برة الـ API. بس حذف المشروع كله لسه شغال (cascade).

### ECO / ECR

- **حالات الـ ECO:** `draft` ← `design_review` ← `production_review` ← `approved` ← `released`. وكمان `rejected`، وبعدها ممكن يرجع draft ويتقدم تاني، و `cancelled`.
- **مين يعمل إيه:**
  - مراجعة التصميم: `eco.approve`.
  - مراجعة الإنتاج: `eco.approve_production`.
  - **اللي كتب التغيير أو قدّمه مايعتمدوش.** وعلشان ده يفضل صح، **محتوى الـ ECO بتاع كاتبه بس:** هو اللي يضيف التغييرات ويقدّمه ويرجّعه draft. ولو حد تاني قدر يحط تغييرات، كان هيقدر يعتمدها بعدين. وكاتب الـ ECO نفسه محتاج `eco.submit` أو `ecr.submit` في كل خطوة، يعني صلاحية «قراءة بس» أو مجموعة مأرشفة بتوقفه زي أي حد. والإلغاء مسموح لكاتب الـ ECO، أو للي معاه `bom.release`.
  - الرفض لازم يكون معاه سبب.
  - مراجعتين في نفس الوقت لنفس المرحلة بيتحسبوا مرة واحدة بس (تحديث مشروط بالحالة).
- **التغييرات:** `add` (قطعة جديدة)، و `change` (قطعة مكان قطعة، زي revision جديد)، و `remove`. الـ ECO لازم يكون فيه تغيير واحد على الأقل قبل ما يتقدم.
- **الـ release** (`bom.release`، والـ ECO معتمد):
  - بينسخ آخر BOM اتعمله release.
  - بيطبّق التغييرات عليه.
  - بيعمل release للنتيجة كـ revision جديد، مكتوب عليه «ECN ECO-00x».
  - كل ده في transaction واحدة. لو تغيير مش متوافق مع الـ BOM الحالي (القطعة موجودة أصلًا، أو مش موجودة علشان تتغير)، العملية كلها بتترفض.
- **الـ ECR:** الفني يقدر يعمله (`ecr.submit`). بيعدّي على نفس المراجعات، بس مالوش release ومابيغيّرش الـ BOM.

### العميل (الضيف) في مشروع Hardware

العميل بيشوف **التقدم بس**: المراحل وحالتها والـ checklist، وعدادات الـ overview. مابيشوفش أسماء ولا ملاحظات قرارات الـ gate. وأي حاجة تانية (القطع، والـ BOM، والـ ECO، والـ builds، والوحدات، والاختبارات، والـ firmware) بترجّع `403 guest_progress_only`.

### الـ Builds والوحدات والاختبارات

- **الـ build** (`builds.manage`): بيتعمل من BOM اتعمله release بس. الاسم (زي EVT1) فريد في المشروع. وله حالات: planned، parts_ordered، assembling، received، testing، complete، cancelled.
- **الوحدات:**
  - بتتسجل بسيريالات صريحة، أو بعدد + بادئة (`PB-001`…).
  - **عدد الوحدات مايعدّيش كمية الـ build.** الكمية بتتشيّك جوه transaction.
  - السيريال فريد جوه الـ build.
  - **حالة الوحدة:** نجحت أو فشلت بتيجي من نتيجة متسجلة. تغيير الحالة باليد (rework أو scrapped) للي معاه `builds.manage` بس. الفني يقدر يعدّل الـ firmware والمكان.
  - إرسال قيمة فاضية (`""`) بيمسح الحقل: المكان، والـ firmware، والـ CM، والتاريخ، والـ MPN، والمورّد، والفئة.
- **خطط الاختبار:** بيعملها اللي معاه `tests.record` أو `tests.approve`، وبيعتمدها اللي معاه `tests.approve`. **اللي كتب الخطة مايعتمدهاش.**
- **النتيجة** (`tests.record`):
  - النتيجة pass أو fail. الـ fail لازم يكون معاه ملاحظة.
  - الوحدة بتاخد النتيجة كحالة ليها.
  - **إصدار الـ firmware بيتنسخ مع النتيجة**، فالفشل بيقولك التركيبة بالظبط: هاردوير إيه مع firmware إيه.

### Firmware ↔ Hardware

`hw_fw_compat`: tag الـ firmware ↔ BOM revision اتعمله release (`firmware.link`).

### الشاشات

- **`/g/:gid/p/:pid` في مجموعة Hardware** فيها تبويبات: المراحل (مع الـ gates والـ checklist وتوافق الـ firmware)، و BOM (الـ revisions والقطع)، و ECO، و Builds، والاختبارات.
- **المهام** بقت على `/g/:gid/p/:pid/tasks`.
- **صفحات التفاصيل:**
  - `/bom/:rid`: سطور الـ BOM، والتعديل في الـ draft، والـ release.
  - `/eco/:eid`: التغييرات، والمراجعة بالمرحلتين، والـ release.
  - `/builds/:bid`: الحالة، والوحدات، وتسجيل النتايج.
- **`/g/:gid/settings/phases`:** قالب المراحل.
- **الأزرار** بتظهر حسب صلاحيات المشروع اللي راجعة من `GET .../hw/overview`.

**لسه، وجاي في 4ب أو بعدها:**
- tag المرحلة على كل مهمة.
- مرفقات ملفات التصميم (Gerbers و drawings).
- إشعار ECN لأعضاء المشروع.
- اقتراح «ضيف المرحلة دي؟» للمشاريع اللي عدّت مكان المرحلة الجديدة. حاليًا المرحلة الجديدة بتنزل في الآخر.
- تقييد مين يعتمد الـ gate بالـ approval matrix و quorum. حاليًا أي حد معاه `gate.decide`.

## 11.5 المرحلة 4ب: اللي اتنفذ (المشتريات والمخزن)

**الـ branch:** `v11.0`. **الـ migration:** `0006_inventory.sql`.

### على مستوى المجموعة (مشترك بين مشاريعها)

- **الموردين** (`inv_vendors`): الاسم فريد في المجموعة من غير فرق بين الحروف الكبيرة والصغيرة. لكل مورّد بيانات تواصل، ومدة توريد افتراضية من 0 لـ 365 يوم. وممكن يتأرشف.
  - مين يقدر يعدّل: `vendors.manage`، يعني المشتريات والقائد والمساعدين.
  - مين يقدر يشوف: أي عضو، ما عدا العميل.
- **الرصيد:**
  - الرصيد بيتحسب بـ **رقم القطعة**، مش برقم القطعة في مشروع معين. السبب: نفس الريل على الرف بيخدم أكتر من مشروع.
  - الرصيد = مجموع الحركات.
  - **الحركات (`inv_movements`) بتتضاف بس**: triggers في قاعدة البيانات بترفض أي تعديل أو حذف، والتصحيح بيبقى حركة `adjust` جديدة. بس حذف المجموعة كلها لسه شغال.
  - `GET /v1/groups/{gid}/stock` بيرجّع لكل قطعة: الرصيد في كل مكان، والمحجوز لكل المشاريع، والمتاح.
- **الحركات باليد** (`POST /v1/groups/{gid}/stock/movements`):
  - **استلام وصرف ونقل بين مكانين:** `inventory.move`، والفني يقدر.
  - **التسوية (+ أو −):** `vendors.manage`، ولازم يكون معاها سبب.
  - الرصيد في أي مكان مش بينزل تحت الصفر.
  - **الصرف باليد مش بياخد من كمية محجوزة لمشروع.** الكمية المحجوزة بتتصرف من الـ build اللي حاجزها.
- **سجل الحركات:** آخر 200 حركة. حركات المشروع الخاص اللي انت مش عضو فيه **مش بتظهر خالص**. ولا رقم القطعة، ولا الكمية، ولا الملاحظة، ولا اسم اللي عملها.
- **المحجوز في الرصيد** مش بيحسب حجوزات المشاريع الخاصة اللي مش شايفها. والسيرفر لسه بيطبق المتاح الحقيقي لما تحجز، بس رسالة الرفض مش بتكشف أرقام المجموعة.
- **الحذف:** لو مشروع أو build أو مستخدم اتحذف، الحركة بتفضل في السجل، والرابط بيه بس هو اللي بيتمسح. قيد «الإضافة بس» بيسمح بالحالة دي وبس.
- **حد اعتماد أوامر الشراء والعملة** (`inv_settings`): القائد والمساعدين بس (`group.manage`).
  - أي أمر شراء **مبلغه زي الحد أو أكتر** محتاج اعتماد.
  - الحد الافتراضي **0**، يعني كل الأوامر محتاجة اعتماد لحد ما الـ lead يغيّره.
  - **أي تغيير في الحد بيتسجل في النشاط.** ليه؟ اللي بيرفع الحد بيسمح لأوامر أكبر تتطلب من غير اعتماد.
  - المورّد اللي اتأرشف مينفعش يتقدّم ليه أمر شراء.

### على مستوى المشروع

**أوامر الشراء:**

```
draft → (submit) → pending_approval → (approve) → ordered → partially_received → received → closed
                 ↘ ordered (لو أقل من الحد)                       · cancelled (قبل أي استلام)
```

- **المسودة:** يفتحها `po.request` (المهندسين اللي معاهم `bom.edit`) أو `po.create` (المشتريات).
- **التعديل:** اللي فتح المسودة، أو `po.create`.
- **التقديم:** `po.create` بس. ولازم كل السطور يكون ليها سعر.
- **الاعتماد:** `po.approve`. **اللي كتب الأمر أو قدّمه مايعتمدوش.** ولو اتنين اعتمدوا في نفس الوقت، بيتحسب مرة واحدة.
- **الأسعار والإجمالي** بيظهروا للي معاه `prices.view` بس. الفني بيشوف أوامر الشراء من غير أسعار.
- **الاستلام** (`inventory.move`):
  - بيزوّد الرصيد في المكان المحدد.
  - **الكمية بتتحجز تلقائي للمشروع**، وللـ build بتاع الأمر لو ليه build.
  - مينفعش تستلم أكتر من المطلوب.
- **القفل:** بعد ما يوصل جزء أو كله. **الإلغاء:** قبل أي استلام.

**الحجز والصرف:**

- **الحجز والصرف لـ build لسه مابدأش التجميع بس** (planned / parts_ordered). ولما الـ build يتلغي، حجوزاته بترجع للمجموعة.
- **الحجز** (`builds.manage`): بيشيّك إن المتاح كفاية (الرصيد − كل الحجوزات في المجموعة)، والتشييك والكتابة في نفس الـ transaction. يعني مشروعين مايقدروش يحجزوا نفس الكمية. وممكن الحجز يتلغي.
- **صرف الـ build** (`POST .../builds/{bid}/issue`):
  - بيصرف كل الحجوزات بتاعة الـ build، من أكبر مكان فيه رصيد الأول.
  - كل ده في transaction واحدة: لو الرصيد الفعلي على الرف أقل من المحجوز، مفيش حاجة بتتصرف خالص.
  - وبعدها الـ build بيبقى «بيتجمّع».

**الاحتياج** (`GET .../hw/demand`):
- بيحسب سطور الـ BOM × كمية كل build مخطط.
- وجنب كل قطعة: المحجوز للمشروع، واللي في الطريق (أوامر شراء لسه ماوصلتش)، والمتاح في المجموعة، والعجز.
- **«اطلب دلوقتي»:** لو فيه عجز وتاريخ الـ build − مدة التوريد ≤ النهارده. مدة التوريد بتيجي من المورّد اللي اسمه زي اسم مورّد القطعة.

**العميل:** مالوش أي حاجة من دول.

### الشاشات
- **`/g/:gid/inventory`:** الرصيد، والموردين، والحركات، وحد الاعتماد. الدخول ليها من رئيسية مجموعة الـ Hardware.
- **تبويب «المشتريات» في المشروع:** الاحتياج (بعلامة «اطلب دلوقتي»)، وأوامر الشراء، والحجوزات.
- **`/g/:gid/p/:pid/po/:poid`:** السطور، والتقديم، والاعتماد، والاستلام، والقفل، والإلغاء.
- **شاشة الـ build:** زرار «صرف القطع المحجوزة وبدء التجميع».

**لسه:**
- حالات أوامر الشراء قابلة للتعديل: حاليًا الحالات ثابتة (التصميم بيقول `workflow_states` للـ entity `po`).
- عملات كتير في نفس المجموعة.
- تكلفة الـ build من الأسعار الفعلية لأوامر الشراء.

## 11.6 المرحلة 5 (الجزء الأول): ربط المشاريع بين المجموعات

**الـ branch:** `v12.0`. **الـ migration:** `0007_project_links.sql`.

- **مين يطلب ومين يوافق:**
  - القائد أو مساعد في مجموعة (`group.manage`) بيطلب ربط مشروع عنده بمشروع في مجموعة تانية، في نفس مساحة العمل.
  - القائد أو مساعد في **المجموعة التانية** هو اللي يوافق. الطرف اللي طلب مايقدرش يوافق على طلبه.
  - أي طرف يقدر يلغي الربط في أي وقت، وده بيستخدم كمان للرفض ولسحب الطلب.
  - بعد الإلغاء ينفع تطلب تاني.
- **مفيش غير ربط واحد شغال بين أي مشروعين**، مهما كان مين اللي طلب. ده متضمن بـ unique index على `(min, max)` للزوج.
- **الاقتراحات للربط** (`.../links/candidates`):
  - بتعرض مشاريع المجموعات التانية في نفس مساحة العمل بس.
  - **المشروع الخاص مش بيظهر خالص**، ومش بيتقبل كهدف حتى لو حد بعت رقمه.
  - ولا المشروع أو المجموعة المتأرشفين.
- **الربط بيدّي ملخص بس** (`.../links/{lid}/summary`)، ولما يكون شغال بس:
  - اسم المشروع ومجموعته ونوعها، وعدد المهام المفتوحة واللي خلصت.
  - **ولو المشروع Hardware:** المراحل وحالتها، وآخر BOM اتعمله release، ومصفوفة توافق الـ firmware.
  - **مابيدّيش أبدًا:** قايمة المهام، ولا سطور الـ BOM، ولا الأسعار، ولا الأعضاء. وشاشات المشروع التاني نفسها لسه بترفض.
- **الاعتماديات بين المشروعين:**
  - مهمة عندنا ممكن تبقى مستنية مهمة عندهم (محتاج `tasks.edit` على مشروعنا).
  - علشان تختار المهمة، الشاشة بتجيب مهامهم المفتوحة، بالعنوان والحالة بس.
  - كل طرف بيشوف الاعتماديات من ناحيته.
  - الاعتماد بيتمسح من الطرف اللي عنده المهمة المستنية.
- **العميل (الضيف):** مالوش أي حاجة من الربط.
- **لما مشروع يتحول لخاص،** كل الربط بتاعه بيتلغي هو والاعتماديات، في نفس الـ transaction. والملخص والمهام بيتجابوا لمشروع ظاهر للمجموعة بس، حتى لو فضل ربط قديم.
- **إلغاء الربط بيمسح الاعتماديات**، علشان لو اتعمل ربط جديد بين نفس المشروعين يبدأ من الصفر.
- **المجموعة أو المشروع المتأرشف** مايطلبوش ربط ومايوافقوش عليه. والموافقة بترفض لو المشروع اللي طلب اتأرشف أو اتحول لخاص بعد الطلب.
- **مصفوفة الـ firmware في الملخص** بتعرض الـ revisions اللي اتعملها release بس.

**الشاشات:**
- `/g/:gid/p/:pid/links`: الطلبات، والموافقة، والإلغاء. الدخول ليها من شاشة المشروع: زرار في مشروع الـ Hardware، وسطر في مشروع الـ Software.
- `/g/:gid/p/:pid/links/:lid`: الملخص والاعتماديات.

## 12. القرارات

| # | السؤال | القرار | التفاصيل |
|---|---|---|---|
| 1 | المجموعة مستوى جديد ولا هي الـ workspace نفسه؟ | **مستوى جديد تحت الـ workspace.** الربط بين مجموعات Hardware و Software **استثنائي** | القسم 3 و 3.1 |
| 2 | المجموعة مشروع واحد ولا أكتر؟ | **أكتر من مشروع**، ولو فيها مشروع واحد بيفتح على طول | القسم 3، القرار 2 |
| 3 | المراحل والحالات ثابتة ولا قابلة للتعديل؟ | **قابلة للتعديل والإضافة على مستوى المجموعة**، والقالب نقطة بداية بس | القسم 7.1 و 7.3 |
| 4 | المشتريات والمخزن؟ | **Hardware بس، وفي الإصدار الأول (المرحلة 4ب).** الطلب والحجز على مستوى المشروع، والمخزن والموردين مشتركين على مستوى المجموعة | القسم 7.5 |
| 5 | حدود الخطط؟ | **العادية: 10 مجموعات. المدفوعة: 50 مجموعة بسعر 60 دولار في الشهر.** الأعضاء مفتوح في الخطتين | القسم 3.2 |
| 6 | العميل؟ | **guest على مستوى المشروع بس.** لازم كل مشروع يتشارك معاه صراحة | القسم 4.7 |
| 7 | الـ firmware؟ | **مشروع جوه مجموعة الـ Hardware**، ومتوصل بـ GitHub | القسم 7.4 |
| 8 | حد مبلغ اعتماد الـ PO؟ | **كل مجموعة تحدده** في `groups.settings` | القسم 7.5 |

---

## المصادر

- Stage-Gate: [Cooper / PDMA 2026](https://community.pdma.org/blogs/robert-cooper/2026/02/03/stage-gate-the-official-2026-version)، [Fictiv](https://www.fictiv.com/ebooks/stage-gate-product-development-guide)، [Asana](https://asana.com/resources/stage-gate-process)
- EVT/DVT/PVT: [Instrumental handbook](https://instrumental.com/build-better-handbook/evt-dvt-pvt)، [exit criteria](https://instrumental.com/build-better-handbook/failed-npi-build-exit-criteria)، [Formlabs](https://formlabs.com/blog/validation-testing-product-development-poc-evt-dvt-pvt-mp/)
- ECR / ECO: [PTC](https://ptc.com/en/blogs/plm/what-is-an-engineering-change-request)، [Duro](https://medium.com/duro-labs/guide-to-plm-based-engineering-change-orders-and-release-management-for-hardware-companies-217958e65aad)، [Autodesk](https://www.autodesk.com/blogs/design-and-manufacturing/engineering-change-management-process/)
- BOM و revisions: [Arena](https://www.arenasolutions.com/resources/articles/bill-of-materials-example/)، [OpenBOM](https://www.openbom.com/blog/revision-control-in-multi-level-bills-of-materials-boms)
- الشهادات: [Predictable Designs](https://predictabledesigns.com/how-long-it-really-takes-to-certify-your-product/)
- أدوار تيم الهاردوير: [Instrumental](https://instrumental.com/build-better-handbook/building-hardware-development-team)
- Jira للهاردوير: [Altium](https://resources.altium.com/p/jira-for-hardware-development)، [CoLab](https://www.colabsoftware.com/post/why-jira-alone-cant-manage-your-design-process)
- الهياكل والصلاحيات: [GitHub nested teams](https://github.blog/news-insights/product-news/nested-teams-add-depth-to-your-team-structure/)، [GitHub org roles](https://docs.github.com/en/organizations/managing-peoples-access-to-your-organization-with-roles/roles-in-an-organization)، [Linear sub-teams](https://linear.app/docs/sub-teams)، [ClickUp permissions](https://help.clickup.com/hc/en-us/articles/6309221065495-Permissions-in-detail)، [ClickUp guests](https://help.clickup.com/hc/en-us/articles/6311803642903-Use-ClickUp-as-a-guest)، [Jira team-managed](https://support.atlassian.com/jira-software-cloud/docs/what-are-next-gen-project-settings/)
- RBAC: [WorkOS](https://workos.com/blog/rbac-best-practices)
- Onboarding للمدعوين: [Appcues](https://appcues.com/blog/user-onboarding-strategies-invited-users)

> **ملحوظة على المصادر:** أغلبها مواد من شركات أدوات (Instrumental، Arena، Duro). أسماء المراحل والمعتمدين بتختلف من شركة لشركة، فالمصفوفات فوق **اقتراح افتراضي** قابل للتعديل من الـ approval matrix، مش معيار ثابت.
