-- Analisis Performa Campaign Marketing D2C Brand
-- Tools: SQL (Duckdb)

-- Suatu brand sedang menjalankan campaign pemasaran melalui beberapa channel digital.

-- Analisis bertujuan mengevaluasi performa campaign, membandingkan efektivitas channel pemasaran, mengukur
-- efisiensi pengeluaran iklan, serta mengidentifikasi campaign dengan performa terbaik.

-- Hasil analisis digunakan untuk mendukung evaluasi strategi pemasaran dan alokasi anggaran iklan.

-- 1. Campaign apa saja yang aktif selama kuartal IV 2024?
SELECT
    name,
    campaign_type,
    start_date,
    end_date,
    total_budget
FROM campaigns
WHERE start_date < DATE '2025-01-01'
  AND end_date >= DATE '2024-10-01'
ORDER BY start_date;

-- 2. Berapa total pengeluaran iklan dan revenue yang dihasilkan setiap campaign?

SELECT 
  c.name AS campaign_name, 
  SUM(dm.spend) AS total_spend,
  SUM(dm.revenue) AS total_revenue
FROM daily_metrics dm
JOIN campaigns c ON dm.campaign_id = c.id
GROUP BY c.name
ORDER BY SUM(dm.revenue) DESC;

-- 3. Bagaimana efektivitas setiap channel berdasarkan CTR dan conversion rate?
SELECT
    ch.name AS channel_name,
    SUM(dm.impressions) AS total_impressions,
    SUM(dm.clicks) AS total_clicks,
    SUM(dm.conversions) AS total_conversions,
    ROUND(SUM(dm.clicks) * 100.0 / SUM(dm.impressions), 2) AS ctr,
    ROUND(SUM(dm.conversions) * 100.0 / SUM(dm.clicks), 2) AS conversion_rate
FROM channels ch
JOIN daily_metrics dm ON ch.id = dm.channel_id
GROUP BY ch.id, ch.name
ORDER BY ctr DESC;

-- 4. Bagaimana tren pengeluaran iklan dan revenue setiap bulan?
SELECT 
  DATE_TRUNC('month', metric_date) AS bulan,
  SUM(spend) AS total_spend, 
  SUM(revenue) AS total_revenue
FROM daily_metrics
GROUP BY DATE_TRUNC('month', metric_date)
ORDER BY total_spend DESC;

-- 5. Campaign mana yang menghasilkan ROAS tertinggi dan mana yang perlu dievaluasi?

SELECT 
c.name as campaign_name,
  SUM(dm.spend) AS total_spend,
  SUM(dm.revenue) AS total_revenue,
  ROUND(SUM(dm.revenue)/SUM(dm.spend),2) AS roas,
  CASE 
    WHEN ROUND(SUM(dm.revenue)/SUM(dm.spend),2) > 3.0 THEN 'Sangat Bagus'
    WHEN ROUND(SUM(dm.revenue)/SUM(dm.spend),2) >= 1.0 THEN 'Cukup'
    ELSE 'Rugi'
  END AS kategori_roas
FROM daily_metrics dm 
JOIN campaigns c ON dm.campaign_id = c.id
GROUP BY c.name
ORDER BY roas DESC;


-- 6. Bagaimana segmentasi performa channel berdasarkan conversion rate?
SELECT 
  ch.name AS channel_name,
  SUM(dm.spend) AS total_spend,
  SUM(dm.revenue) AS total_revenue,
  ROUND(SUM(dm.conversions)*100.0/sum(dm.clicks),2) AS conversion_rate,
  CASE 
      WHEN ROUND(SUM(dm.conversions)*100.0/sum(dm.clicks),2) > 6 THEN 'High Performer'
      WHEN ROUND(SUM(dm.conversions)*100.0/sum(dm.clicks),2) >= 3 THEN 'Medium Performer'
      WHEN ROUND(SUM(dm.conversions)*100.0/sum(dm.clicks),2) <3 THEN 'Low Performer'
    END AS segmentasi
  
FROM daily_metrics dm 
JOIN channels ch ON ch.id = dm.channel_id
GROUP BY ch.name
ORDER BY ROUND(SUM(dm.conversions)*100.0/sum(dm.clicks),2) DESC;

-- 7. Tipe campaign mana yang menghasilkan ROAS tertinggi?
SELECT 
  c.campaign_type,
  COUNT(DISTINCT c.id) AS jumlah_campaign,
  SUM(dm.spend) AS total_spend,
  SUM(dm.revenue) AS total_revenue,
  ROUND(SUM(dm.revenue)/SUM(dm.spend),2) AS roas,
  CASE 
      WHEN ROUND(SUM(dm.revenue)/SUM(dm.spend),2) > 5.0 THEN 'Sangat Efisien'
      WHEN ROUND(SUM(dm.revenue)/SUM(dm.spend),2) > 2.0 THEN 'Efisien'
      WHEN ROUND(SUM(dm.revenue)/SUM(dm.spend),2) > 1.0 then 'Kurang Efisien'
      ELSE 'Tidak Efisien'
    END AS grading
FROM daily_metrics dm
JOIN campaigns c ON c.id = dm.campaign_id
GROUP BY c.campaign_type
ORDER BY ROUND(SUM(dm.revenue)/SUM(dm.spend),2) DESC;


-- 8. Apa tiga campaign dengan ROAS tertinggi?
WITH campaign_summary AS (
    SELECT
        c.name AS campaign_name,
        SUM(dm.revenue) AS total_revenue,
        SUM(dm.spend) AS total_spend
    FROM campaigns c
    JOIN daily_metrics dm ON c.id = dm.campaign_id
    GROUP BY c.id, c.name
)
SELECT
    campaign_name,
    total_spend,
    total_revenue,
    ROUND(total_revenue / total_spend, 2) AS roas
FROM campaign_summary
ORDER BY roas DESC
LIMIT 3;


-- 9. Channel mana yang menghasilkan ROAS tertinggi pada setiap tipe campaign?
WITH campaign_summary AS (
    SELECT
        c.campaign_type AS campaign_type,
        ch.name AS channel_name,
        SUM(dm.revenue) AS total_revenue,
        SUM(dm.spend) AS total_spend
    FROM campaigns c
    JOIN daily_metrics dm ON c.id = dm.campaign_id
    JOIN channels ch ON dm.channel_id = ch.id
    GROUP BY c.campaign_type, ch.name 
)
SELECT
    campaign_type,
    channel_name,
    total_spend,
    total_revenue,
    ROUND(total_revenue / total_spend, 2) AS roas
FROM campaign_summary
ORDER BY campaign_type, roas DESC;

-- 10. Bagaimana menyusun ringkasan performa campaign untuk evaluasi rutin?
WITH campaign_metrics AS (
    SELECT
        c.name AS campaign_name,
        SUM(dm.spend) AS total_spend,
        SUM(dm.revenue) AS total_revenue,
        SUM(dm.impressions) AS total_impressions,
        SUM(dm.clicks) AS total_clicks,
        SUM(dm.conversions) AS total_conversions
   
FROM campaigns c
    JOIN daily_metrics dm ON c.id = dm.campaign_id
   
GROUP BY c.id, c.name
),
campaign_report AS (
    SELECT
        campaign_name,
        total_spend,
        total_revenue,
        ROUND(total_revenue / total_spend, 2) AS roas,
        ROUND(total_clicks * 100.0 / total_impressions, 2) AS ctr,
        ROUND(total_conversions * 100.0 / total_clicks, 2) AS conversion_rate,
        CASE
            WHEN total_revenue / total_spend > 5.0 THEN 'Star'
            WHEN total_revenue / total_spend > 2.0 THEN 'Profitable'
            WHEN total_revenue / total_spend > 1.0 THEN 'Break Even'
            ELSE 'Needs Review'
        END AS status
FROM campaign_metrics
)
SELECT
    campaign_name,
    total_spend,
    total_revenue,
    roas,
    ctr,
    conversion_rate,
    status
FROM campaign_report
ORDER BY roas DESC;


-- Insight & rekomendasi

-- 1. Email Marketing memiliki conversion rate tertinggi, menunjukkan potensi subscriber sebagai audiens bernilai
-- yang dapat dioptimalkan melalui pengembangan email list dan email sequence.
-- 2. TikTok Ads menghasilkan impressions tinggi, tetapi CTR rendah, sehingga diperlukan A/B testing pada format konten kreatif
-- dan hook untuk meningkatkan engagement.
-- 3. Flash Sale dan Brand Awareness memiliki tujuan berbeda, sehingga evaluasi performanya perlu disesuaikan
-- dengan indikator keberhasilan masing-masing campaign.