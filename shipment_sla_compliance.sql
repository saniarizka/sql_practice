
-- Analisis Kinerja Pengiriman, Kepatuhan SLA, dan Efisiensi Operasional Ekspedisi

-- Tools: SQL (DuckDB)

-- Studi kasus perusahaan ekspedisi dengan beberapa pilihan layanan pengiriman dan jaringan hub antar kota.

-- Analisis bertujuan mengevaluasi ketepatan waktu pengiriman, mengidentifikasi tahapan operasional yang berpotensi menjadi
-- bottleneck, serta menemukan rute dengan kontribusi keterlambatan terbesar.

-- Hasil analisis digunakan untuk menyusun rekomendasi perbaikan proses operasional dan layanan pelanggan.

-- 1. Seberapa baik setiap layanan memenuhi target waktu pengiriman (SLA)?

SELECT 
    l.nama AS layanan,
    l.sla_jam,

    COUNT(CASE
        WHEN p.status = 'terkirim'
        THEN 1
    END) AS paket_terkirim,

    COUNT(CASE
        WHEN p.status = 'terkirim'
         AND date_diff('hour', p.waktu_pickup, p.waktu_terkirim) <= l.sla_jam
        THEN 1
    END) AS tepat_waktu,

    ROUND(
        100.0 * COUNT(CASE
            WHEN p.status = 'terkirim'
             AND date_diff('hour', p.waktu_pickup, p.waktu_terkirim) <= l.sla_jam
            THEN 1
        END)
        / COUNT(CASE
            WHEN p.status = 'terkirim'
            THEN 1
        END),
        1
    ) AS on_time_rate,

    ROUND(
        AVG(CASE
            WHEN p.status = 'terkirim'
            THEN date_diff('hour', p.waktu_pickup, p.waktu_terkirim)
        END),
        1
    ) AS rata_jam_kirim

FROM pengiriman p
JOIN layanan l
    ON l.kode = p.layanan_kode

GROUP BY
    l.nama,
    l.sla_jam;

-- 2. Apakah ketepatan waktu pengiriman berbeda antar rute
SELECT 
    h1.kota AS kota_asal,
    h2.kota AS kota_tujuan,

    COUNT(CASE 
        WHEN p.status = 'terkirim' 
        THEN 1 
    END) AS paket_terkirim,

    ROUND(
        100.0 * COUNT(CASE 
            WHEN p.status = 'terkirim'
             AND date_diff(
                    'hour', 
                    p.waktu_pickup, 
                    p.waktu_terkirim
                 ) <= l.sla_jam
            THEN 1 
        END)
        / COUNT(CASE 
            WHEN p.status = 'terkirim' 
            THEN 1 
        END),
        1
    ) AS on_time_rate

FROM pengiriman p 
JOIN hub h1 
    ON p.hub_asal_id = h1.id
JOIN hub h2 
    ON p.hub_tujuan_id = h2.id
JOIN layanan l 
    ON p.layanan_kode = l.kode

GROUP BY
    h1.kota, 
    h2.kota
HAVING 
  paket_terkirim>=4
ORDER BY on_time_rate ASC, h1.kota, h2.kota;

-- 3. Bagaimana distribusi waktu pada setiap tahapan proses pengiriman
SELECT
    l.nama AS layanan, 
    
    ROUND(AVG(CASE 
        WHEN p.status = 'terkirim'
        THEN date_diff('hour', p.waktu_pickup, p.waktu_masuk_hub_asal)
    END), 1) AS jam_penjemputan,

    ROUND(AVG(CASE 
        WHEN p.status = 'terkirim'
        THEN date_diff('hour', p.waktu_masuk_hub_asal, p.waktu_keluar_hub_asal)
    END), 1) AS jam_proses_hub_asal,

    ROUND(AVG(CASE 
        WHEN p.status = 'terkirim'
        THEN date_diff('hour', p.waktu_keluar_hub_asal, p.waktu_masuk_hub_tujuan)
    END), 1) AS jam_perjalanan,

    ROUND(AVG(CASE 
        WHEN p.status = 'terkirim'
        THEN date_diff('hour', p.waktu_masuk_hub_tujuan, p.waktu_terkirim)
    END), 1) AS jam_antar_akhir

FROM pengiriman p
JOIN layanan l 
    ON p.layanan_kode = l.kode

GROUP BY l.nama

ORDER BY jam_perjalanan DESC;

-- 4. Hub mana yang memiliki rata-rata waktu pemrosesan paket tertinggi?
SELECT 
  h.nama AS hub, h.wilayah as wilayah, 
  COUNT(p.id) as paket_diproses,
  ROUND(AVG(date_diff('hour', p.waktu_masuk_hub_asal, p.waktu_keluar_hub_asal)),1) AS rata_jam_proses,
  ROUND(MAX(date_diff('hour', p.waktu_masuk_hub_asal, p.waktu_keluar_hub_asal)),1) AS proses_terlama_jam
FROM hub h
JOIN pengiriman p
ON p.hub_asal_id = h.id
WHERE status = 'terkirim'
GROUP BY h.nama, h.wilayah
ORDER BY rata_jam_proses DESC;


-- 5. Apakah hari penjemputan berkaitan dengan tingkat keterlambatan pengiriman?

SELECT
    dayname(p.waktu_pickup) AS hari_pickup,

    COUNT(CASE 
        WHEN p.status = 'terkirim' 
        THEN 1 
    END) AS paket_terkirim,

    COUNT(CASE 
        WHEN p.status = 'terkirim'
         AND date_diff('hour', p.waktu_pickup, p.waktu_terkirim) > l.sla_jam 
        THEN 1 
    END) AS terlambat,

    ROUND(
        100.0 * COUNT(CASE 
            WHEN p.status = 'terkirim'
             AND date_diff('hour', p.waktu_pickup, p.waktu_terkirim) > l.sla_jam 
            THEN 1 
        END)
        / COUNT(CASE 
            WHEN p.status = 'terkirim' 
            THEN 1 
        END),
        1
    ) AS persen_terlambat

FROM pengiriman p
JOIN layanan l 
    ON p.layanan_kode = l.kode

GROUP BY hari_pickup

ORDER BY persen_terlambat DESC;

-- 6. Bagaimana distribusi paket terlambat berdasarkan durasi keterlambatannya?
SELECT 
    CASE 
        WHEN status = 'terkirim' 
             AND date_diff('hour', p.waktu_pickup, p.waktu_terkirim) <= l.sla_jam 
            THEN 'Tepat waktu'
            
        WHEN status = 'terkirim' 
             AND date_diff('hour', p.waktu_pickup, p.waktu_terkirim) <= l.sla_jam + 4 
            THEN 'Telat 1-4 jam'
            
        WHEN status = 'terkirim' 
             AND date_diff('hour', p.waktu_pickup, p.waktu_terkirim) <= l.sla_jam + 8 
            THEN 'Telat 5-8 jam'
            
        WHEN status = 'terkirim' 
             AND date_diff('hour', p.waktu_pickup, p.waktu_terkirim) > l.sla_jam + 8 
            THEN 'Telat > 8 jam'
    END AS kategori,

    COUNT(*) AS jumlah_paket,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS persen

FROM pengiriman p
JOIN layanan l 
    ON p.layanan_kode = l.kode

WHERE status = 'terkirim'

GROUP BY kategori

ORDER BY 
    CASE kategori
        WHEN 'Tepat waktu' THEN 1
        WHEN 'Telat 1-4 jam' THEN 2
        WHEN 'Telat 5-8 jam' THEN 3
        WHEN 'Telat > 8 jam' THEN 4
    END;

-- 7. Rute mana yang berkontribusi paling besar terhadap total keterlambatan pengiriman?

WITH paket_terlambat AS (
    SELECT
        p.hub_asal_id,
        p.hub_tujuan_id
    FROM pengiriman p
    JOIN layanan l
        ON l.kode = p.layanan_kode
    WHERE date_diff(
        'hour',
        p.waktu_pickup,
        p.waktu_terkirim
    ) > l.sla_jam
),

per_rute AS (
    SELECT
        h1.kota AS kota_asal,
        h2.kota AS kota_tujuan,
        COUNT(*) AS paket_terlambat
    FROM paket_terlambat pt
    JOIN hub h1
        ON h1.id = pt.hub_asal_id
    JOIN hub h2
        ON h2.id = pt.hub_tujuan_id
    GROUP BY
        h1.kota,
        h2.kota
)

SELECT
    kota_asal,
    kota_tujuan,
    paket_terlambat,

    ROUND(
        100.0 * paket_terlambat
        / SUM(paket_terlambat) OVER (),
        1
    ) AS persen_dari_total_telat,

    ROUND(
        100.0 * SUM(paket_terlambat) OVER (
            ORDER BY paket_terlambat DESC, kota_asal, kota_tujuan
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
        / SUM(paket_terlambat) OVER (),
        1
    ) AS kumulatif_persen

FROM per_rute

ORDER BY
    paket_terlambat DESC,
    kota_asal,
    kota_tujuan;

-- insight -> rekomendasi
-- 1. layanan Sameday memiliki tingkat ketepatan waktu terendah (40%), dengan sebagian besar durasi pengiriman terjadi di luar perjalanan.
-- 2. Rata-rata waktu pengiriman layanan YES (23 jam) mendekati batas SLA 24 jam.
-- 3. Hub Medan memiliki rata-rata waktu pemrosesan tertinggi dibandingkan hub lainnya.
-- 4. Tiga rute menyumbang 62,5% dari total keterlambatan, sehingga menjadi prioritas untuk evaluasi operasional.
-- 5. Sebagian besar paket terlambat hanya melampaui SLA selama 1–4 jam, sehingga komunikasi proaktif kepada pelanggan dapat menjadi salah satu upaya perbaikan layanan.


