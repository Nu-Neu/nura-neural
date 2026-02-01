<#
.SYNOPSIS
    Tests the n8n workflow 02_agent_source with mock data

.DESCRIPTION
    Sends mock content data to the Agent Source workflow webhook
    to test IMTT analysis without requiring database records.

.EXAMPLE
    .\test-workflow-mock.ps1
    
.EXAMPLE
    .\test-workflow-mock.ps1 -N8nUrl "http://localhost:5678"
#>

param(
    [string]$N8nUrl = "https://api.irdecode.com",
    [string]$WebhookPath = "webhook/agent-source"
)

$ErrorActionPreference = "Stop"

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Testing WF-02: Agent Source - IMTT Evaluation" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# ===================================================
# MOCK DATA - Simulates content from various sources
# ===================================================

$MockContent = @{
    # Farsi News Article (Mock)
    farsi_news = @{
        content_id = [guid]::NewGuid().ToString()
        source_id = [guid]::NewGuid().ToString()
        url = "https://example-news.ir/article/12345"
        title = "گزارش جدید درباره توسعه اقتصادی در منطقه"
        content_text = @"
تهران - خبرگزاری مثال

بر اساس گزارش‌های منتشر شده، توسعه اقتصادی در منطقه خاورمیانه با چالش‌های جدیدی مواجه شده است.

کارشناسان اقتصادی معتقدند که تحریم‌های بین‌المللی تأثیر قابل توجهی بر رشد اقتصادی داشته است. به گفته یک مقام ارشد، «ما شاهد تغییرات مهمی در ساختار اقتصادی هستیم.»

منابع آگاه اعلام کردند که دولت در حال بررسی راهکارهای جدید برای مقابله با این چالش‌ها است. این گزارش همچنین به افزایش 15 درصدی صادرات غیرنفتی در سه ماهه گذشته اشاره می‌کند.

تحلیلگران غربی این ادعاها را با تردید نگاه می‌کنند و خواستار ارائه اسناد و مدارک بیشتر شده‌اند.
"@
        language = "fa"
        detected_language = "fa"
        text_direction = "rtl"
        author_name = "خبرنگار اقتصادی"
        published_at = (Get-Date).AddHours(-6).ToString("yyyy-MM-ddTHH:mm:ssZ")
        word_count = 180
        ingested_at = (Get-Date).AddHours(-5).ToString("yyyy-MM-ddTHH:mm:ssZ")
        source_type = "news_agency"
        source_domain = "example-news.ir"
        source_name = "خبرگزاری مثال"
        source_name_original = "خبرگزاری مثال"
        source_country = "IR"
        source_language = "fa"
        current_tier = "unverified"
        source_description = "A mock Iranian news agency for testing"
        prev_independence = $null
        prev_methodology = $null
        prev_transparency = $null
        prev_triangulation = $null
        prev_overall_score = $null
        last_evaluated_at = $null
    }

    # English Reuters-style Article (Mock)
    english_reuters = @{
        content_id = [guid]::NewGuid().ToString()
        source_id = [guid]::NewGuid().ToString()
        url = "https://mock-reuters.com/world/middle-east/2026/02/01/economic-report"
        title = "Middle East Economic Growth Faces New Challenges, Report Says"
        content_text = @"
DUBAI, Feb 1 (Mock Reuters) - Economic growth in the Middle East faces significant headwinds in 2026, according to a new report from the International Monetary Fund released on Saturday.

The IMF's World Economic Outlook update projects GDP growth of 2.8% for the MENA region, down from earlier estimates of 3.2%, citing ongoing geopolitical tensions and fluctuating oil prices.

"The region's economies are showing resilience, but structural reforms remain essential," said Jihad Azour, Director of the IMF's Middle East and Central Asia Department, in an interview with Mock Reuters.

Key findings from the report include:
- Oil-exporting countries expected to see 2.5% growth, down from 3.1%
- Non-oil sector growth projected at 3.8%
- Inflation expected to moderate to 5.2% by year-end

The UAE and Saudi Arabia are leading diversification efforts, with Vision 2030 initiatives showing early progress. However, the report warns that "geopolitical risks remain elevated" in the region.

Analysts at JP Morgan echoed similar concerns in a separate note to clients, suggesting investors maintain a cautious stance on regional equities.

(Reporting by Mock Correspondent; Editing by Mock Editor)
"@
        language = "en"
        detected_language = "en"
        text_direction = "ltr"
        author_name = "Mock Correspondent"
        published_at = (Get-Date).AddHours(-3).ToString("yyyy-MM-ddTHH:mm:ssZ")
        word_count = 220
        ingested_at = (Get-Date).AddHours(-2).ToString("yyyy-MM-ddTHH:mm:ssZ")
        source_type = "news_agency"
        source_domain = "mock-reuters.com"
        source_name = "Mock Reuters"
        source_name_original = "Mock Reuters"
        source_country = "UK"
        source_language = "en"
        current_tier = "credible"
        source_description = "A mock international news agency for testing"
        prev_independence = 0.85
        prev_methodology = 0.90
        prev_transparency = 0.88
        prev_triangulation = 0.82
        prev_overall_score = 0.86
        last_evaluated_at = (Get-Date).AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    # Arabic Opinion Piece (Mock - potentially biased)
    arabic_opinion = @{
        content_id = [guid]::NewGuid().ToString()
        source_id = [guid]::NewGuid().ToString()
        url = "https://mock-arabic-news.com/opinion/analysis-456"
        title = "الأزمة الاقتصادية وتأثير القوى الغربية"
        content_text = @"
بقلم: محلل سياسي

تشهد المنطقة العربية تحديات اقتصادية غير مسبوقة، وهي نتيجة مباشرة للتدخلات الغربية المستمرة في شؤوننا الداخلية.

إن السياسات الاستعمارية الجديدة التي تتبعها الدول الغربية تهدف إلى إضعاف اقتصاداتنا وجعلنا تابعين لها. هذه ليست مجرد نظرية مؤامرة، بل حقيقة موثقة يؤكدها الخبراء.

يقول المحللون إن الحصار الاقتصادي المفروض على بعض الدول العربية هو شكل من أشكال الحرب الاقتصادية. الأرقام واضحة: انخفضت قيمة العملات بنسبة 40% في بعض البلدان.

على الشعوب العربية أن تستيقظ وتدرك أن مستقبلها بيدها. الوحدة العربية هي السبيل الوحيد للخروج من هذه الأزمة.

المصدر: تحليل خاص
"@
        language = "ar"
        detected_language = "ar"
        text_direction = "rtl"
        author_name = "محلل سياسي"
        published_at = (Get-Date).AddHours(-12).ToString("yyyy-MM-ddTHH:mm:ssZ")
        word_count = 150
        ingested_at = (Get-Date).AddHours(-11).ToString("yyyy-MM-ddTHH:mm:ssZ")
        source_type = "blog"
        source_domain = "mock-arabic-news.com"
        source_name = "أخبار عربية مثال"
        source_name_original = "أخبار عربية مثال"
        source_country = "LB"
        source_language = "ar"
        current_tier = "unverified"
        source_description = "A mock Arabic opinion site for testing"
        prev_independence = $null
        prev_methodology = $null
        prev_transparency = $null
        prev_triangulation = $null
        prev_overall_score = $null
        last_evaluated_at = $null
    }
}

# ===================================================
# Select test case
# ===================================================

Write-Host "`nAvailable mock content samples:" -ForegroundColor Yellow
Write-Host "  1. Farsi News Article (fa) - Neutral economic news"
Write-Host "  2. English Reuters-style (en) - High credibility source"
Write-Host "  3. Arabic Opinion Piece (ar) - Potentially biased content"
Write-Host ""

$selection = Read-Host "Select sample (1-3) or press Enter for all"

$testCases = @()
switch ($selection) {
    "1" { $testCases = @($MockContent.farsi_news) }
    "2" { $testCases = @($MockContent.english_reuters) }
    "3" { $testCases = @($MockContent.arabic_opinion) }
    default { $testCases = @($MockContent.farsi_news, $MockContent.english_reuters, $MockContent.arabic_opinion) }
}

# ===================================================
# Test webhook connectivity first
# ===================================================

Write-Host "`nTesting n8n connectivity..." -ForegroundColor Yellow
$testUrl = "$N8nUrl/healthz"
try {
    $healthCheck = Invoke-RestMethod -Uri $testUrl -Method Get -TimeoutSec 10 -ErrorAction SilentlyContinue
    Write-Host "✅ n8n is accessible at $N8nUrl" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Could not reach n8n health endpoint. Proceeding anyway..." -ForegroundColor Yellow
}

# ===================================================
# Send mock data to webhook
# ===================================================

$webhookUrl = "$N8nUrl/$WebhookPath"
Write-Host "`nWebhook URL: $webhookUrl" -ForegroundColor Cyan

foreach ($content in $testCases) {
    Write-Host "`n─────────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host "Testing: $($content.source_name) ($($content.language))" -ForegroundColor Yellow
    Write-Host "Title: $($content.title)" -ForegroundColor Gray
    Write-Host "Content ID: $($content.content_id)" -ForegroundColor Gray
    Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $body = @{
        # Webhook expects content_id in body, but for mock test we send full content
        content_id = $content.content_id
        # Include full mock data for direct processing (bypass DB lookup)
        mock_data = $content
        _test_mode = $true
    } | ConvertTo-Json -Depth 10

    try {
        Write-Host "Sending POST request..." -ForegroundColor Cyan
        
        $response = Invoke-RestMethod -Uri $webhookUrl -Method Post `
            -Body $body `
            -ContentType "application/json" `
            -TimeoutSec 120 `
            -ErrorAction Stop

        Write-Host "`n✅ Response received:" -ForegroundColor Green
        Write-Host ($response | ConvertTo-Json -Depth 5) -ForegroundColor White

        # Parse key results
        if ($response.imtt_scores) {
            Write-Host "`n📊 IMTT Scores:" -ForegroundColor Cyan
            Write-Host "  Independence:   $($response.imtt_scores.independence.score) / 1.0" -ForegroundColor White
            Write-Host "  Methodology:    $($response.imtt_scores.methodology.score) / 1.0" -ForegroundColor White
            Write-Host "  Transparency:   $($response.imtt_scores.transparency.score) / 1.0" -ForegroundColor White
            Write-Host "  Triangulation:  $($response.imtt_scores.triangulation.score) / 1.0" -ForegroundColor White
            Write-Host "  ─────────────────" -ForegroundColor Gray
            Write-Host "  Total Score:    $($response.total_score) / 1.0" -ForegroundColor Yellow
            Write-Host "  Credibility:    $($response.credibility_tier)" -ForegroundColor Yellow
        }

        if ($response.claims_count -gt 0) {
            Write-Host "`n📝 Extracted Claims: $($response.claims_count)" -ForegroundColor Cyan
        }

        if ($response.needs_escalation) {
            Write-Host "`n⚠️  ESCALATION NEEDED: $($response.escalation_reason)" -ForegroundColor Red
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message
        
        Write-Host "`n❌ Request failed:" -ForegroundColor Red
        Write-Host "  Status Code: $statusCode" -ForegroundColor Red
        Write-Host "  Error: $errorMessage" -ForegroundColor Red
        
        if ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                Write-Host "  Response Body: $responseBody" -ForegroundColor Red
            }
            catch {}
        }
    }
}

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Complete" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
