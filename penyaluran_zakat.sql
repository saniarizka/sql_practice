-- Analisis Donasi dan Penyaluran Zakat Ramadan
--
-- Suatu lembaga penyaluran zakat sedang menganalisis data donasi dan distribusi bantuan.
-- Analisis menggunakan SQL untuk mengevaluasi penghimpunan donasi, segmentasi donatur, pola waktu donasi, serta
-- pemerataan penyaluran bantuan kepada penerima.
--
-- Tools: SQL

-- 1. Berapa jumlah donatur, total transaksi, dan total donasi yang terkumpul selama Ramadan?
SELECT 
  COUNT(DISTINCT donatur_id) AS total_donatur,
  COUNT(DISTINCT id) AS total_transaksi,
  SUM(jumlah) AS total_donasi
FROM donasi;

-- 2. Bagaimana komposisi donasi berdasarkan kategori Zakat Fitrah, Zakat Maal, Infaq, dan Sedekah?
SELECT 
  kd.nama_kategori,
  COUNT(d.id) AS jumlah_transaksi,
  SUM(d.jumlah) AS total_donasi
FROM donasi d
JOIN kategori_donasi kd ON kd.id = d.kategori_id
GROUP BY kd.nama_kategori;

-- 3. bagaimana segmentasi donatur berdasarkan total kontribusi selama Ramadan?
WITH per_donatur AS (
  SELECT 
    dr.nama, 
    dr.kota,
    SUM(d.jumlah) AS total_donasi
  FROM donasi d 
  JOIN donatur dr ON d.donatur_id = dr.id 
  GROUP BY dr.nama, dr.kota
)
SELECT
nama, kota, total_donasi,
CASE 
  WHEN total_donasi >= 5000000 THEN 'Platinum'
  WHEN total_donasi >= 2000000 THEN 'Gold'
  WHEN total_donasi >= 500000 THEN 'Silver'
  ELSE 'Bronze'
END AS tier 
FROM per_donatur
ORDER BY total_donasi DESC;

-- 4. Siapa donatur dengan kontribusi terbesar di setiap kota?
WITH donatur_total AS (
    SELECT
        dn.nama,
        dn.kota,
        SUM(d.jumlah) AS total_donasi
FROM donasi d
    JOIN donatur dn ON d.donatur_id = dn.id
   
GROUP BY dn.id, dn.nama, dn.kota
)
SELECT
    nama,
    kota,
    total_donasi,
    DENSE_RANK() OVER (PARTITION BY kota
ORDER BY total_donasi DESC) AS ranking_kota
FROM donatur_total
ORDER BY kota, ranking_kota;

-- 5. Bagaimana tren penghimpunan donasi harian selama Ramadan?
SELECT
    tanggal,
    SUM(jumlah) AS donasi_harian,
    SUM(SUM(jumlah)) OVER (ORDER BY tanggal) AS kumulatif
FROM donasi
GROUP BY tanggal
ORDER BY tanggal;

-- 6. Apakah terdapat perbedaan penghimpunan donasi antara 20 hari pertama dan 10 hari terakhir Ramadan?
SELECT
    CASE
        WHEN tanggal >= '2025-03-21' THEN '10 Hari Terakhir'
        ELSE 'Sebelumnya'
    END AS periode,
    COUNT(*) AS jumlah_transaksi,
    SUM(jumlah) AS total_donasi,
    ROUND(AVG(jumlah), 0) AS rata_rata_donasi
FROM donasi
GROUP BY
    CASE
        WHEN tanggal >= '2025-03-21' THEN '10 Hari Terakhir'
        ELSE 'Sebelumnya'
    END
ORDER BY periode;

-- 7. Bagaimana distribusi bantuan berdasarkan kategori penerima zakat?
SELECT 
  p.kategori_mustahik,
  COUNT(d.id) AS jumlah_penyaluran,
  SUM(d.jumlah) AS total_disalurkan
FROM distribusi d
JOIN penerima p ON p.id = d.penerima_id
GROUP BY p.kategori_mustahik;


-- 8. Berapa persentase donasi yang telah disalurkan dibandingkan total donasi yang terkumpul?

WITH total_masuk AS (
    SELECT SUM(jumlah) AS total_donasi
	FROM donasi
),
total_keluar AS (
    SELECT SUM(jumlah) AS total_distribusi
	FROM distribusi
)
SELECT
    tm.total_donasi,
    tk.total_distribusi,
    ROUND(tk.total_distribusi * 100.0 / tm.total_donasi,
    		2)
    AS persentase_tersalurkan
FROM total_masuk tm
CROSS JOIN total_keluar tk;

-- 9. Kategori mustahik mana yang memiliki rata-rata penerimaan bantuan terendah?
SELECT 
  p.kategori_mustahik,
  count(distinct d.penerima_id) as jumlah_penerima,
  sum(d.jumlah) as total_disalurkan,
  ROUND(SUM(d.jumlah)/COUNT(distinct d.penerima_id),0) as rata_rata_per_penerima
from penerima p
LEFT join distribusi d on p.id = d.penerima_id
group by p.kategori_mustahik
order by ROUND(SUM(d.jumlah)/COUNT(distinct d.penerima_id),0) ASC;

-- 10. Bagaimana kontribusi setiap kategori donasi dan klasifikasi prioritasnya dalam laporan eksekutif?

WITH ringkasan_donasi AS (
    SELECT
        k.nama_kategori,
        COUNT(*) AS jumlah_transaksi,
        SUM(d.jumlah) AS total_donasi,
        ROUND(SUM(d.jumlah) * 100.0 / SUM(SUM(d.jumlah)) OVER (), 2) AS persentase_kontribusi
   
FROM donasi d
    JOIN kategori_donasi k ON d.kategori_id = k.id
   
GROUP BY k.nama_kategori
)
SELECT
    nama_kategori,
    jumlah_transaksi,
    total_donasi,
    persentase_kontribusi,
    CASE
        WHEN persentase_kontribusi >= 30 THEN 'Utama'
        WHEN persentase_kontribusi >= 15 THEN 'Signifikan'
        ELSE 'Pendukung'
    END AS klasifikasi
FROM ringkasan_donasi
ORDER BY total_donasi DESC;
