# App Store Listing — PancreasGuard

## App Name
PancreasGuard

## Subtitle (30 characters max)
Pancreatitis Symptom Tracker

## Category
Health & Fitness

## Price
Free (with in-app purchases)

## In-App Purchases
- PancreasGuard Premium — $29.99/year (7-day free trial)
- PancreasGuard Premium — $4.99/month

## Keywords (100 characters max)
pancreatitis,pancreas,symptom,tracker,health,HRV,heart,rate,flare,diet,pain,chronic,acute,digestive

---

## Description

PancreasGuard is the first app designed specifically for people living with pancreatitis. It combines Apple Watch health monitoring with intelligent symptom tracking to help you spot flare patterns early — before they become emergencies.

SMART MONITORING
Your Apple Watch continuously tracks heart rate, heart rate variability (HRV), blood oxygen, temperature, and activity. PancreasGuard watches for the warning signs research has linked to pancreatitis flares — like sustained elevated heart rate and dropping HRV — and alerts you when multiple signals align. The app learns your personal baselines over time, so it knows what's abnormal for *you*, not just population averages.

AI FOOD SCANNER
Snap a photo of your meal or drink. On-device AI identifies the food, flags high-fat content and alcohol, and logs it automatically. No typing, no searching databases. Works completely offline on your device.

SYMPTOM DIARY
Log pain level, location, nausea, vomiting, fever, and digestive changes in seconds — right from your Apple Watch or iPhone. Everything is timestamped and correlated with your biometric data.

RISK SCORING
Our multi-signal risk engine weighs 10 different indicators based on published medical research to give you a clear green/yellow/orange/red status. It's not a diagnosis — it's an early warning system that helps you decide when to call your doctor.

MULTI-DAY TREND DETECTION
Single readings can be noisy. PancreasGuard tracks patterns across days — a rising heart rate trend, HRV declining over 3 days, or activity dropping for 48 hours straight. When multiple signals converge over multiple days, the app escalates its warning level. This multi-day approach is what caught warning signs 3-4 days before hospitalization in real-world testing.

ON-DEVICE AI INSIGHTS
On devices running iOS 27+, PancreasGuard uses Apple's on-device AI to analyze your complete health picture — current signals, multi-day trends, dietary triggers, and symptom history — and provides a plain-language explanation of what your data means. The AI reasoning stays entirely on your device.

WORKS WITH YOUR OTHER APPS
PancreasGuard reads dietary data from MyFitnessPal, DrinkCount, and any app that writes to Apple Health. When you log food or symptoms in PancreasGuard, it writes back to Apple Health too. No double entry.

SHARE WITH YOUR DOCTOR
Generate a health report with your biometric trends, symptom history, flare events, and dietary patterns. Share it directly with your healthcare provider.

RESEARCH-BACKED. REAL-WORLD TESTED.
The risk engine is grounded in peer-reviewed research — including a study on heart rate elevation in pancreatitis (Nature Scientific Reports, 2024) and an active NIH clinical trial on HRV for early pancreatic disease detection (NCT04400903).

For this initial release, the engine was validated against 3 years (1,102 days) of real Apple Watch data from a single patient with two acute pancreatitis hospitalizations. It's an N=1 case study — not a clinical trial — but the results are promising: RED alerts fired 3-4 days before each hospitalization, a confirmed heavy alcohol episode was correctly flagged as high-risk, and the tuned engine produces fewer than 2 ambiguous alerts per year.

We're transparent about the limitations. This is a starting point. A future version will offer opt-in anonymized data sharing so the risk engine can learn from the broader pancreatitis community and improve detection for everyone.

YOUR DATA STAYS YOURS
All processing happens on your device. No accounts, no cloud uploads, no data selling. Your health information never leaves your iPhone.

---

PancreasGuard is a health companion tool and does not diagnose, treat, or prevent any medical condition. Always consult your healthcare provider for medical decisions. If you experience severe symptoms, seek emergency medical care immediately.

---

## Promotional Text (170 characters, can be updated without app review)
Research-backed. Real-world tested. On-device AI learns your personal baselines and detects multi-day warning patterns — all processed privately on your device.

## What's New (for updates)
• Adaptive baselines: the engine learns what's normal for YOU over time — personalized thresholds replace one-size-fits-all
• Multi-day trend detection: rising HR, declining HRV, and activity drops tracked across days, not just snapshots
• On-device AI insights (iOS 27+): plain-language analysis of your risk picture with clinical reasoning
• AI Food Scanner: photograph your meal — on-device AI identifies it, estimates fat content, detects alcohol
• Full Apple Health integration: reads AND writes dietary and symptom data

---

## App Privacy — Data Linked to You
- Health & Fitness (HealthKit data — used for core app functionality)

## App Privacy — Data Not Collected
All data stays on device. No analytics, no tracking, no third-party SDKs.

---

## Age Rating
12+ (Medical/Treatment Information)

## Support URL
https://github.com/sk8er02/PancreasGuard

## Review Notes for Apple
This app reads HealthKit data (heart rate, HRV, blood oxygen, wrist temperature, step count, respiratory rate, dietary nutrition, symptoms) and writes symptom categories and dietary data back to HealthKit. All data processing occurs on-device. The app uses the Foundation Models framework (iOS 27+) for two features: (1) on-device food image recognition, and (2) AI-powered risk context analysis that provides natural-language insights when risk is elevated. Both features degrade gracefully on pre-27 devices — the core risk scoring engine, adaptive baselines, and temporal pattern detection are pure Swift with no AI dependency and work on iOS 17+. The risk scoring system is based on published medical research and validated against 1,102 days of real Apple Watch data from a user with two confirmed acute pancreatitis hospitalizations (January 2026, June 2026). The engine detected elevated risk (RED alerts) 3-4 days before each hospitalization and correctly identified a confirmed high-risk alcohol episode — while producing fewer than 2 ambiguous alerts per year after signal tuning. The original engine was tuned based on false positive analysis: resting heart rate replaced average heart rate as the primary signal (0.8% vs 28.4% daily fire rate), and SpO2 thresholds were adjusted to account for Apple Watch sensor noise. Full validation methodology is documented in ValidationReport.md. The app is clearly presented as a health companion tool, not a diagnostic device. Medical disclaimers are shown during onboarding and accessible from Settings.
