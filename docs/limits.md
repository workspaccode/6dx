# حدود الـ API

كل الأرقام في مكان واحد في الكود: [`backend/internal/api/limits.go`](../backend/internal/api/limits.go). حدود الطلبات في الدقيقة بتتغير من `.env` من غير ما تبني الكود تاني.

| الحد | القيمة | لما يتعدّى | بيتغير من |
|---|---|---|---|
| إيميلات في طلب دعوة واحد | **50** | `400 too_many_invites` | `limits.go` |
| دعوات معلّقة في الـ workspace | **500** | `409 pending_invites_limit` | `limits.go` |
| طول الإيميل | **254** حرف، ولازم يكون صالح (`mail.ParseAddress`) | `400 invalid_email` + الإيميل الغلط | `limits.go` |
| الإيميلات المكررة في نفس الطلب | بتتدمج في دعوة واحدة (من غير فرق بين الحروف الكبيرة والصغيرة) | — | — |
| اسم المشروع | **1 – 80** حرف | `400 name_too_long` | `limits.go` |
| وصف المشروع | **2000** حرف | `400 description_too_long` | `limits.go` |
| اسم الـ repository | `owner/name` بصيغة GitHub، و ≤ 140 حرف | `400 invalid_repository` | `limits.go` |
| عنوان المهمة | **1 – 200** حرف | `400 title_too_long` | `limits.go` |
| وصف المهمة | **10000** حرف | `400 description_too_long` | `limits.go` |
| مشروع المهمة | لازم يكون في نفس الـ workspace | `404 project_not_found` | — |
| حجم أي JSON body | **1MB** | `413 body_too_large` | `httpx.go` |
| حجم body لـ `device-token` | **4KB**، والكود ≤ 256 حرف | `400` | `auth_flow.go` |
| طلبات تسجيل الدخول (`/auth/github/*`) | **30 / دقيقة / IP** | `429 rate_limited` + `Retry-After` | `RATE_LIMIT_SIGNIN_PER_MIN` |
| طلبات الـ API (`/v1/*`) | **600 / دقيقة / IP** | `429 rate_limited` + `Retry-After` | `RATE_LIMIT_API_PER_MIN` |
| مدة الطلب | قراءة 30s، كتابة 60s، idle 120s | السيرفر بيقفل الاتصال | `cmd/api/main.go` |
| حجم الـ headers | **64KB** | `431` | `cmd/api/main.go` |
| webhook من GitHub | **25MB** | التوقيع بيفشل | `github.go` |
| حالات المهام في المجموعة | **20** حالة شغالة | `409 state_limit_reached` | `workflow.go` |
| اسم حالة المهمة | **1 – 40** حرف، ومفيش اسمين زي بعض في نفس المجموعة | `400 invalid_state_name` / `409 state_name_taken` | `workflow.go` |
| لون حالة المهمة | `#RRGGBB` | `400 invalid_color` | `workflow.go` |
| مراحل قالب الـ Hardware | **15** مرحلة، والاسم **1 – 40** حرف | `409 phase_limit_reached` | `hw.go` |
| بنود الـ checklist للمرحلة | **30** بند، كل بند ≤ **200** حرف | `400 checklist_too_long` | `hw.go` |
| القطع في المشروع | **5000** قطعة. رقم القطعة ≤ 64، والوصف ≤ 200، والـ revision ≤ 8 | `409 part_limit_reached` | `hw_bom.go` |
| كمية سطر الـ BOM أو الـ build | **1 – 100000** | `400 invalid_quantity` | `hw_bom.go` / `hw_builds.go` |
| تسجيل وحدات في طلب واحد | **500**، والإجمالي ≤ كمية الـ build | `400 invalid_count` / `409 units_exceed_quantity` | `hw_builds.go` |
| عنوان الـ ECO أو خطة الاختبار | **1 – 200** حرف. السبب والأثر والمعايير ≤ **5000** | `400` | `hw_eco.go` |
| صلاحية الـ state في ربط GitHub | **10 دقايق**، ومش بتتجدد | "انتهت صلاحية الطلب" | `github.go` |

**الحسابات بالحروف مش بالـ bytes:** الحرف العربي بياخد 2 bytes، فـ 80 حرف عربي مسموح زي 80 حرف إنجليزي.

**ليه الأرقام دي بالذات؟**
- **50 دعوة في المرة:** تكفي تيم كامل، ومش هتقفل قاعدة البيانات على باقي المستخدمين. قاعدة البيانات SQLite باتصال واحد، فطلب فيه 50 ألف إيميل كان بيوقّف الـ API كله.
- **30 طلب دخول في الدقيقة:** الـ device flow بيعمل poll كل 5 ثواني تقريبًا، يعني حوالي 12 طلب في الدقيقة. فـ 30 مساحة كفاية لمستخدمين اتنين ورا نفس الراوتر.
- **600 طلب API في الدقيقة:** فتح التطبيق بيعمل حوالي 10 طلبات. ده مساحة كبيرة لمكتب كامل ورا IP واحد.

**جاي مع مرحلة المجموعات** ([docs/design/groups-and-roles.md](design/groups-and-roles.md)):

| الحد | العادية | المدفوعة (60$ / شهر) |
|---|---|---|
| مجموعات في الـ workspace | 10 | 50 |
| الأعضاء | مفتوح | مفتوح |
